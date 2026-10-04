// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 PowerTools AI contributors

import Foundation

/// Orchestrates one Explain: asks `HealthCoachTriggerPolicy` whether a call
/// is even allowed, shows the pre-send preview the first time a provider
/// sees this content type, then builds, sends, validates and caches the
/// answer — the only place any of this touches a real `AIProvider`
/// (`docs/ai-health-coach/README.md` section 3.4). The header and the
/// detail view only ever read `current`; neither calls a provider directly.
/// Not `@MainActor`-isolated — like `AITextActionPanelController`, callers
/// are expected to be on the main thread already (every real caller is UI
/// code), and `AICancellableRequest.run` hops its own callbacks onto the
/// main actor regardless, so tests can drive this synchronously from a
/// plain (non-isolated) test context.
final class HealthNarratorService: ObservableObject {
    static let shared = HealthNarratorService()

    /// The last validated answer, or nil when nothing has been explained
    /// yet, the last attempt was rejected or failed, or the situation has
    /// since moved on from what it explains. `HealthCoachDetailView`/the
    /// header fall back to the template whenever this is nil or stale.
    @Published private(set) var current: HealthNarration?
    @Published private(set) var isStreaming = false
    /// Set only while a first-time preview is waiting on a decision; the
    /// detail view shows `AIPreSendPreviewSheet` for exactly as long as
    /// this is non-nil.
    @Published private(set) var pendingPreview: AIContextManifest?
    /// Why the last explicit Explain press produced nothing, or nil. Only
    /// ever set for `.explainPressed`: an automatic trigger that is refused
    /// or fails stays silent, since nobody asked for it.
    @Published private(set) var notice: HealthNarratorNotice?

    private var cache: [Set<HealthFinding.Kind>: HealthNarration] = [:]
    private let request = AICancellableRequest()
    private var pendingCall: PendingCall?

    private struct PendingCall {
        let findings: [HealthFinding]
        let journal: HealthActivityJournal
        let provider: AIProvider
        let option: AITextActionsProviderOption
        let kinds: Set<HealthFinding.Kind>
        /// Computed once, in `explain`, from `option.boundary` and the
        /// redaction setting - carried through so `start` (which builds the
        /// prompt) and `finish` (which validates the reply) always resolve
        /// an app's name the same way for one call, per Decision D6.
        let nameForApp: (String) -> String
        /// Whether the person pressed Explain, so a failure later, in
        /// `finish`, knows whether it owes them a notice.
        let explicit: Bool
    }

    private init() {}

    /// Whether `current` still answers the situation described by
    /// `findings` — a changed finding set makes it stale even though it is
    /// still sitting in `current` until the next explain call replaces it.
    func isCurrentStale(for findings: [HealthFinding]) -> Bool {
        current?.findingKinds != Set(findings.map(\.kind))
    }

    func explain(trigger: HealthCoachTrigger, findings: [HealthFinding], journal: HealthActivityJournal,
                settings: HealthCoachTriggerSettings, system: HealthCoachSystemState, now: Date = Date()) {
        let kinds = Set(findings.map(\.kind))
        let configuration = AITextActionsProviderConfiguration.current()
        let option = AITextActionsProviderCatalog.option(for: configuration.kind)
        let decision = HealthCoachTriggerPolicy.decide(
            now: now, findings: findings, trigger: trigger,
            ledger: HealthCoachUsageLedgerService.shared.ledger,
            settings: settings, system: system, providerBoundary: option.boundary)

        let explicit = trigger == .explainPressed
        if explicit { notice = nil }

        switch decision {
        case .useTemplate(let reason):
            current = nil
            if explicit { notice = HealthNarratorNotice(reason) }
        case .useCache:
            current = cache[kinds]
        case .callModel:
            guard let provider = AITextActionsProviderFactory.makeProvider(for: configuration),
                  case .ready = provider.currentAvailability() else {
                current = nil
                if explicit { notice = .providerUnavailable }
                return
            }
            let call = PendingCall(findings: findings, journal: journal, provider: provider,
                                   option: option, kinds: kinds, nameForApp: nameForApp(boundary: option.boundary),
                                   explicit: explicit)
            let manifest = healthSnapshotManifest(findings: findings, journal: journal, option: option,
                                                  nameForApp: call.nameForApp)
            if AIPreSendPreviewTracker.hasShownPreview(contentType: manifest.contentType, providerID: manifest.providerID) {
                start(call)
            } else {
                pendingCall = call
                pendingPreview = manifest
            }
        }
    }

    func confirmPendingPreview() {
        guard let manifest = pendingPreview, let call = pendingCall else { return }
        AIPreSendPreviewTracker.recordPreviewShown(contentType: manifest.contentType, providerID: manifest.providerID)
        pendingPreview = nil
        pendingCall = nil
        start(call)
    }

    func cancelPendingPreview() {
        pendingPreview = nil
        pendingCall = nil
    }

    /// Called when the detail collapses: a notice describes one press, and
    /// "nothing to explain" would be wrong the moment a finding appears.
    func clearNotice() {
        notice = nil
    }

    func cancelStreaming() {
        request.cancel()
        isStreaming = false
        // A stopped request is not a failure to explain, so it leaves no
        // notice; and its partial text must not leak into the next finish.
        lastAccumulatedText = nil
    }

    private func start(_ call: PendingCall) {
        isStreaming = true
        let instructions = HealthNarratorPrompt.instructions
        let healthCoach = FeatureStrings.healthCoach(L10n.shared.language)
        let prompt = HealthNarratorPrompt.prompt(findings: call.findings, journal: call.journal,
                                                 healthCoach: healthCoach, nameForApp: call.nameForApp)
        request.run(
            call.provider.streamText(instructions: instructions, prompt: prompt, maxOutputTokens: 220),
            onUpdate: { [weak self] partial in
                // The raw stream is not shown until it is validated (section
                // 3.4/5): an unvalidated partial answer is never displayed
                // as though it were trusted. `isStreaming` alone drives the
                // "thinking" state the UI shows meanwhile; the cumulative
                // text is only kept so `finish` has the final answer to
                // validate once the stream ends.
                self?.lastAccumulatedText = partial
            },
            onFinish: { [weak self] result in
                self?.finish(result, call: call, prompt: prompt)
            }
        )
    }

    private func finish(_ result: Result<Void, Error>, call: PendingCall, prompt: String) {
        isStreaming = false
        // `AICancellableRequest` only ever hands the caller cumulative text
        // through `onUpdate`; the validator needs the final text, which the
        // last `onUpdate` call already carried, so `start` accumulates it.
        let raw = lastAccumulatedText
        lastAccumulatedText = nil
        guard case .success = result, let raw else {
            current = nil
            if call.explicit { notice = .failed }
            return
        }
        // A request that completed counts against the caps whether or not
        // its reply turns out usable: it reached the provider (and, for a
        // cloud one, was billed), so a provider that keeps answering with
        // something the validator rejects must not be able to run past
        // the hourly and daily limits.
        HealthCoachUsageLedgerService.shared.recordCall(
            findingKinds: call.kinds, estimatedTokens: HealthNarratorPrompt.estimatedTokens(for: prompt))
        guard let narration = HealthNarratorProcessing.process(
            raw: raw, findings: call.findings, kinds: call.kinds,
            providerID: call.option.providerID, providerBoundary: call.option.boundary,
            nameForApp: call.nameForApp)
        else {
            current = nil
            if call.explicit { notice = .replyRejected }
            return
        }
        cache[call.kinds] = narration
        current = narration
    }

    /// Set by `start`'s `onUpdate`, read by `finish` — kept as a plain
    /// property rather than threading the accumulated text through
    /// `AICancellableRequest`'s `onFinish`, which only reports success or
    /// failure, matching every other caller of that type in this app.
    private var lastAccumulatedText: String?

    private func healthSnapshotManifest(findings: [HealthFinding], journal: HealthActivityJournal,
                                        option: AITextActionsProviderOption,
                                        nameForApp: (String) -> String) -> AIContextManifest {
        let strings = FeatureStrings.aiTextActions(L10n.shared.language)
        let healthCoach = FeatureStrings.healthCoach(L10n.shared.language)
        let prompt = HealthNarratorPrompt.prompt(findings: findings, journal: journal, healthCoach: healthCoach,
                                                 nameForApp: nameForApp)
        return AIContextManifestBuilder.healthSnapshot(
            findingCount: findings.count,
            approximateSizeBytes: prompt.utf8.count,
            option: option,
            contentTypeLabel: healthCoach.narratorPreviewContentTypeLabel,
            retentionLocal: strings.previewRetentionLocal,
            retentionRemote: strings.previewRetentionRemote,
            providerDisplayName: AITextActionsProviderCatalog.displayName(for: option.kind, strings: strings)
        )
    }

    /// `sanitizeName` for on-device or a local server (nothing leaves the
    /// Mac, so there is nothing to redact); a category label for a cloud
    /// provider, unless the person has turned that off (Decision D6,
    /// `docs/ai-health-coach/README.md` section 9 - categories by default,
    /// real names an explicit opt-out).
    private func nameForApp(boundary: AIContextManifest.Boundary) -> (String) -> String {
        guard boundary == .remote,
              UserDefaults.standard.bool(forKey: DefaultsKey.healthCoachRedactAppNamesForCloud)
        else {
            return HealthNarratorPrompt.sanitizeName
        }
        let healthCoach = FeatureStrings.healthCoach(L10n.shared.language)
        return { HealthAppCategoryTable.label(forAppName: $0, strings: healthCoach) }
    }
}
