// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 PowerTools AI contributors

import Foundation

/// The Command Bar text actions: `.enhance` first (added after M2 shipped,
/// the general-purpose "make this better" action people reach for most),
/// then the five roadmap slice 2.8 named. Each is a fixed system prompt sent
/// as `AIProvider.streamText`'s `instructions`, with the selected text
/// itself as `prompt` - never mixed together, so the selection is always
/// treated as data, never as instructions (PRIVACY.md's "Content is treated
/// as data, not instructions").
enum AITextActionKind: String, CaseIterable, Identifiable {
    case enhance
    case rewrite
    case shorten
    case proofread
    case summarise
    case translate

    var id: String { rawValue }

    /// The row title and result-panel header, from one place so the Command
    /// Bar row and the panel that opens from it never disagree on the name.
    func title(strings: AITextActionsFeatureStrings) -> String {
        switch self {
        case .enhance: return strings.actionEnhanceTitle
        case .rewrite: return strings.actionRewriteTitle
        case .shorten: return strings.actionShortenTitle
        case .proofread: return strings.actionProofreadTitle
        case .summarise: return strings.actionSummariseTitle
        case .translate: return strings.actionTranslateTitle
        }
    }

    /// A distinct SF Symbol per action; all long-shipped, safe on macOS 14.
    var symbolName: String {
        switch self {
        case .enhance: return "sparkles"
        case .rewrite: return "pencil"
        case .shorten: return "scissors"
        case .proofread: return "checkmark.seal"
        case .summarise: return "list.bullet"
        case .translate: return "globe"
        }
    }

    /// `targetLanguage` only matters for `.translate`; every other case
    /// ignores it. Translating into the app's own display language is a
    /// deliberate scope decision for the first cut - a language picker is a
    /// real feature, not a one-line addition, and nothing here forecloses
    /// adding one later.
    func instructions(targetLanguage: AppLanguage) -> String {
        switch self {
        case .enhance:
            return "Enhance the user's text: improve clarity, flow and impact while keeping "
                + "its meaning, tone and roughly its length. Reply with only the enhanced "
                + "text - no preamble, no explanation, no quotation marks around it."
        case .rewrite:
            return "Rewrite the user's text to be clearer and more natural, keeping its "
                + "meaning and roughly its length. Reply with only the rewritten text - no "
                + "preamble, no explanation, no quotation marks around it."
        case .shorten:
            return "Shorten the user's text, keeping its key meaning. Reply with only the "
                + "shortened text - no preamble, no explanation, no quotation marks around it."
        case .proofread:
            return "Correct grammar, spelling and punctuation in the user's text without "
                + "changing its meaning, tone or length. Reply with only the corrected text - "
                + "no preamble, no explanation, no quotation marks around it."
        case .summarise:
            return "Summarise the user's text concisely, keeping its most important points. "
                + "Reply with only the summary - no preamble, no explanation, no quotation "
                + "marks around it."
        case .translate:
            return "Translate the user's text into \(targetLanguage.displayName). Reply with "
                + "only the translated text - no preamble, no explanation, no quotation marks "
                + "around it."
        }
    }
}
