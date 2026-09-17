// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 PowerTools AI contributors

import Combine
import Foundation

/// Keeps the activity journal current by subscribing to state services
/// already publish — never a new monitor, matching the plan
/// (`docs/ai-health-coach/`): "adding an event source means subscribing to
/// an existing @Published value." Finding raised/cleared events are the one
/// exception: findings are not themselves published anywhere today, so
/// `noteFindings` is called by whoever already evaluates them live (the
/// header), rather than this service running its own detection loop.
final class HealthActivityJournalService: ObservableObject {
    static let shared = HealthActivityJournalService()

    @Published private(set) var journal = HealthActivityJournal()
    /// Whatever the header last computed, so the detail popover shows the
    /// same findings from the same gate instead of running a second,
    /// independently-timed detector that could disagree with it.
    @Published private(set) var latestFindings: [HealthFinding] = []

    private var cancellables = Set<AnyCancellable>()
    private var recordingStartedAt: Date?
    private var activeFindingKinds: Set<HealthFinding.Kind> = []

    private init() {
        KeepAwakeManager.shared.$isActive
            .removeDuplicates()
            .dropFirst()
            .sink { [weak self] isActive in self?.handleKeepAwake(isActive) }
            .store(in: &cancellables)

        ScreenRecorderService.shared.$isRecording
            .removeDuplicates()
            .dropFirst()
            .sink { [weak self] isRecording in self?.handleRecording(isRecording) }
            .store(in: &cancellables)

        UpdateService.shared.$state
            .removeDuplicates()
            .dropFirst()
            .sink { [weak self] state in
                guard case .available = state else { return }
                self?.record(.updateAvailable)
            }
            .store(in: &cancellables)
    }

    func clear() {
        journal.clear()
    }

    /// Called with whatever the caller already computed live; diffs against
    /// the kinds seen last time and journals only the transitions.
    func noteFindings(_ findings: [HealthFinding]) {
        latestFindings = findings
        let current = Set(findings.map(\.kind))
        for kind in current.subtracting(activeFindingKinds) {
            record(.findingRaised(kind))
        }
        for kind in activeFindingKinds.subtracting(current) {
            record(.findingCleared(kind))
        }
        activeFindingKinds = current
    }

    /// Off by default (D2); called only once a later task wires the
    /// Clipboard History event through its own Settings toggle.
    func noteClipboardCapture(sourceAppName: String) {
        record(.clipboardCaptured(sourceAppName: sourceAppName))
    }

    private func handleKeepAwake(_ isActive: Bool) {
        if isActive {
            let automatic = KeepAwakeManager.shared.sessionTrigger == .automation
            record(.keepAwakeStarted(automatic: automatic))
        } else {
            record(.keepAwakeEnded)
        }
    }

    private func handleRecording(_ isRecording: Bool) {
        if isRecording {
            recordingStartedAt = Date()
            record(.recordingStarted)
        } else {
            let duration = recordingStartedAt.map { Date().timeIntervalSince($0) } ?? 0
            recordingStartedAt = nil
            record(.recordingStopped(duration: duration))
        }
    }

    private func record(_ event: HealthJournalEvent) {
        journal.record(event, at: Date())
    }
}
