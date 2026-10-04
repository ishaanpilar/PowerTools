// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 PowerTools AI contributors

import Foundation

/// Text for the Scratchpad's AI note actions (roadmap slice 3.1). English only
/// for now, like every AI surface: every other language repeats the English
/// text until translation resumes, which is why this is its own type rather
/// than new fields in the fully translated `ScratchpadFeatureStrings`.
struct ScratchpadAIStrings {
    let menuTitle: String
    let summaryTitle: String
    let actionItemsTitle: String
    let structureTitle: String
    let summaryPadName: String
    let actionItemsPadName: String
    let structurePadName: String
    let working: String
    let cancel: String
    let dismiss: String
    /// Shown in the pre-send preview as the kind of content being sent.
    let previewContentType: String
    let emptyNote: String
    let padLimitReached: String
    let emptyReply: String
    let saveFailed: String
}

extension FeatureStrings {
    static func scratchpadAI(_ language: AppLanguage) -> ScratchpadAIStrings {
        switch language {
        case .enUS, .ptBR, .tr, .ru, .es, .de, .fr, .it, .ja, .ko, .zhHans, .zhTW, .zhHK:
            return .enUS
        }
    }
}

extension ScratchpadAIStrings {
    static let enUS = ScratchpadAIStrings(
        menuTitle: "AI",
        summaryTitle: "Summarise",
        actionItemsTitle: "Action items",
        structureTitle: "Structure",
        summaryPadName: "Summary",
        actionItemsPadName: "Action items",
        structurePadName: "Structured",
        working: "Working on a new note…",
        cancel: "Cancel",
        dismiss: "OK",
        previewContentType: "A Scratchpad note",
        emptyNote: "This note is empty, so there is nothing to work with.",
        padLimitReached: "All Scratchpad tabs are in use. Close one, then try again.",
        emptyReply: "The provider sent back an empty answer, so no note was created.",
        saveFailed: "The new note could not be saved. Your existing notes are unchanged."
    )
}
