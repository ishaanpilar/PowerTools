// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 PowerTools AI contributors

import Foundation

/// Whether one chosen clipboard item may be sent for an AI text action
/// (roadmap slice 3.2). Decided before any provider is asked, and before the
/// first-send preview, so a clip that cannot be sent is never half-sent.
enum ClipboardTransformPolicy {
    /// About 3,000 tokens: the roadmap budgets 200-3,900 input tokens for
    /// these actions, which is also what fits the on-device model's
    /// context beside its instructions and its answer. A clip may hold a
    /// million characters, so without a cap one misclick would put an
    /// entire document into a request, or fail on-device with nothing
    /// useful to say.
    static let maximumCharacters = 12_000

    enum Refusal: Equatable {
        case notText
        case empty
        case tooLong
        /// The history's own detector thinks this looks like a secret, and
        /// the chosen provider is not on this Mac.
        case looksSensitiveForRemote
    }

    static func refusal(for entry: ClipboardHistoryEntry,
                        boundary: AIContextManifest.Boundary) -> Refusal? {
        guard entry.kind == .text else { return .notText }
        let text = entry.text.trimmingCharacters(in: .whitespacesAndNewlines)
        if text.isEmpty { return .empty }
        if text.count > maximumCharacters { return .tooLong }
        if boundary == .remote, ClipboardHistorySensitiveText.looksSensitive(text) {
            return .looksSensitiveForRemote
        }
        return nil
    }

    /// Whether a row should offer Transform at all, independent of the
    /// provider: hidden for images and files, which have no text to send.
    static func offersTransform(for entry: ClipboardHistoryEntry) -> Bool {
        entry.kind == .text
            && !entry.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

extension ClipboardTransformPolicy.Refusal {
    func message(strings: AITextActionsFeatureStrings) -> String {
        switch self {
        case .notText, .empty:
            return strings.clipboardEmptyOrNotText
        case .tooLong:
            return String(format: strings.clipboardTooLongFormat, ClipboardTransformPolicy.maximumCharacters)
        case .looksSensitiveForRemote:
            return strings.clipboardSensitiveForRemote
        }
    }
}
