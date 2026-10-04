// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 PowerTools AI contributors

import Combine
import Foundation

/// Runs one Scratchpad AI note action against the AI text actions provider,
/// the same provider, availability checks, first-send preview and failure
/// wording the Command Bar text actions use (`AITextActionPanelController`).
/// The answer is handed to `ScratchpadService.addAIResult`, which can only
/// append a new tab.
final class ScratchpadAIService: ObservableObject {
    static let shared = ScratchpadAIService()

    enum Phase: Equatable {
        case idle
        case previewing(AIContextManifest)
        case running(ScratchpadAIAction)
        case failed(String)
    }

    @Published private(set) var phase: Phase = .idle

    private let request = AICancellableRequest()
    private var pending: (() -> Void)?
    private var lastText: String?

    private init() {}

    func run(_ action: ScratchpadAIAction) {
        guard case .idle = phase, let document = ScratchpadService.shared.documentSnapshot() else { return }
        let strings = FeatureStrings.scratchpadAI(L10n.shared.language)
        let providerStrings = FeatureStrings.aiTextActions(L10n.shared.language)
        if let refusal = ScratchpadAIResult.refusalBeforeSending(document) {
            phase = .failed(refusal.message(strings: strings))
            return
        }
        let note = document.pads.first(where: { $0.id == document.selectedID })?.text ?? ""
        let configuration = AITextActionsProviderConfiguration.current()
        guard let provider = AITextActionsProviderFactory.makeProvider(for: configuration) else {
            phase = .failed(providerStrings.reasonNoProviderConfigured)
            return
        }
        if case .unavailable(let reason) = provider.currentAvailability() {
            phase = .failed(AITextActionsProviderFactory.describe(reason, strings: providerStrings))
            return
        }
        let manifest = AIContextManifestBuilder.scratchpadNote(
            note, option: AITextActionsProviderCatalog.option(for: configuration.kind),
            strings: providerStrings, contentTypeLabel: strings.previewContentType)
        let send = { [weak self] in self?.start(action, note: note, provider: provider) }
        if AIPreSendPreviewTracker.hasShownPreview(contentType: manifest.contentType, providerID: manifest.providerID) {
            send()
        } else {
            pending = {
                AIPreSendPreviewTracker.recordPreviewShown(contentType: manifest.contentType,
                                                           providerID: manifest.providerID)
                send()
            }
            phase = .previewing(manifest)
        }
    }

    func confirmPreview() {
        let send = pending
        pending = nil
        send?()
    }

    /// Cancel from the preview, the running state, or to dismiss a failure.
    func dismiss() {
        request.cancel()
        pending = nil
        lastText = nil
        phase = .idle
    }

    private func start(_ action: ScratchpadAIAction, note: String, provider: AIProvider) {
        phase = .running(action)
        lastText = nil
        request.run(
            provider.streamText(instructions: action.instructions, prompt: note, maxOutputTokens: nil),
            onUpdate: { [weak self] partial in self?.lastText = partial },
            onFinish: { [weak self] result in self?.finish(result, action: action) }
        )
    }

    private func finish(_ result: Result<Void, Error>, action: ScratchpadAIAction) {
        let reply = lastText ?? ""
        lastText = nil
        switch result {
        case .success:
            if let refusal = ScratchpadService.shared.addAIResult(reply, for: action) {
                phase = .failed(refusal.message(strings: FeatureStrings.scratchpadAI(L10n.shared.language)))
            } else {
                phase = .idle
            }
        case .failure(let error):
            let generationError = error as? AIGenerationError ?? .other(String(describing: error))
            phase = .failed(AITextActionsProviderFactory.describe(
                generationError, strings: FeatureStrings.aiTextActions(L10n.shared.language)))
        }
    }
}
