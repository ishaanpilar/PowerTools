// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 PowerTools AI contributors

import Foundation

/// One thing PowerTools itself did or noticed. Never the clipboard's content,
/// never a file path, never a window title — only what the plan
/// (`docs/ai-health-coach/`) explicitly allows a journal entry to carry.
enum HealthJournalEvent: Equatable {
    case keepAwakeStarted(automatic: Bool)
    case keepAwakeEnded
    case recordingStarted
    case recordingStopped(duration: TimeInterval)
    case findingRaised(HealthFinding.Kind)
    case findingCleared(HealthFinding.Kind)
    case updateAvailable
    /// Only ever the source app's name (task 09, off by default, D2) — never
    /// the item's content, never an app the person has told Clipboard
    /// History to ignore.
    case clipboardCaptured(sourceAppName: String)
}

struct HealthActivityJournalEntry: Equatable {
    let event: HealthJournalEvent
    let occurredAt: Date
}

/// An in-memory ring buffer of what PowerTools itself has done or noticed
/// recently — never written to disk, never exported, never sent unless the
/// person asks for an explanation and the preview shows it (a later task).
/// Newest first.
struct HealthActivityJournal: Equatable {
    static let maximumEntries = 50
    static let maximumAge: TimeInterval = 2 * 60 * 60

    private(set) var entries: [HealthActivityJournalEntry] = []

    mutating func record(_ event: HealthJournalEvent, at occurredAt: Date) {
        entries.insert(HealthActivityJournalEntry(event: event, occurredAt: occurredAt), at: 0)
        prune(now: occurredAt)
    }

    mutating func clear() {
        entries.removeAll()
    }

    /// Called independently of `record` so a journal that simply sits open
    /// for two hours ages entries out even without a new event arriving.
    mutating func prune(now: Date) {
        let cutoff = now.addingTimeInterval(-Self.maximumAge)
        entries.removeAll { $0.occurredAt < cutoff }
        if entries.count > Self.maximumEntries {
            entries.removeLast(entries.count - Self.maximumEntries)
        }
    }
}
