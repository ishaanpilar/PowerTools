// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 PowerTools AI contributors

import Foundation

/// Turns one journal event into the one line the detail popover shows for
/// it, from only what the event itself carries.
enum HealthJournalTemplate {
    static func text(for event: HealthJournalEvent, strings: HealthCoachStrings) -> String {
        switch event {
        case .keepAwakeStarted(let automatic):
            return automatic ? strings.journalKeepAwakeStartedAutomatic : strings.journalKeepAwakeStartedManual
        case .keepAwakeEnded:
            return strings.journalKeepAwakeEnded
        case .recordingStarted:
            return strings.journalRecordingStarted
        case .recordingStopped(let duration):
            return String(format: strings.journalRecordingStoppedFormat, Self.durationText(duration))
        case .clipboardCaptured(let sourceAppName):
            return String(format: strings.journalClipboardCapturedFormat, sourceAppName)
        case .findingRaised(let kind):
            return String(format: strings.journalFindingRaisedFormat, strings.label(for: kind))
        case .findingCleared(let kind):
            return String(format: strings.journalFindingClearedFormat, strings.label(for: kind))
        case .updateAvailable:
            return strings.kindLabelUpdateAvailable
        }
    }

    private static func durationText(_ duration: TimeInterval) -> String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = duration >= 3600 ? [.hour, .minute] : [.minute, .second]
        formatter.unitsStyle = .abbreviated
        formatter.zeroFormattingBehavior = .dropLeading
        return formatter.string(from: max(0, duration)) ?? "0s"
    }
}
