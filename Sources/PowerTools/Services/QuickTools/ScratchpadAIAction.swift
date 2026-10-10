// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 PowerTools AI contributors

import Foundation

/// The Scratchpad's AI note actions (roadmap slice 3.1). Each sends the active
/// note as `prompt` and a fixed `instructions` string, never mixed, so the note
/// is always data. The answer only ever becomes a new tab: nothing here can
/// change, replace or delete an existing note, whatever the note or the answer
/// says.
enum ScratchpadAIAction: String, CaseIterable, Identifiable {
    case summary
    case actionItems
    case structure

    var id: String { rawValue }

    func title(strings: ScratchpadAIStrings) -> String {
        switch self {
        case .summary: return strings.summaryTitle
        case .actionItems: return strings.actionItemsTitle
        case .structure: return strings.structureTitle
        }
    }

    func padName(strings: ScratchpadAIStrings) -> String {
        switch self {
        case .summary: return strings.summaryPadName
        case .actionItems: return strings.actionItemsPadName
        case .structure: return strings.structurePadName
        }
    }

    var symbolName: String {
        switch self {
        case .summary: return "text.alignleft"
        case .actionItems: return "checklist"
        case .structure: return "list.bullet.indent"
        }
    }

    /// The note, fenced and followed by a one-line reminder of the task. A
    /// bare note gave the on-device model nothing to tell data from task, and
    /// it answered with the instructions themselves.
    func prompt(forNote note: String) -> String {
        "Note:\n\"\"\"\n\(note)\n\"\"\"\n\nNow do the task on the note above. "
            + "Do not repeat the instructions."
    }

    var instructions: String {
        switch self {
        case .summary:
            return "Summarise the user's note in a few short Markdown bullet points, keeping "
                + "its most important points. Reply with only the summary, no preamble."
        case .actionItems:
            return "List the concrete tasks, decisions and follow-ups in the user's note as a "
                + "Markdown checklist, one \"- [ ] \" line each. If there are none, reply "
                + "\"- [ ] No action items found\". Reply with only the list, no preamble, and "
                + "never repeat these instructions."
        case .structure:
            return "Reorganise the user's note into clear Markdown with headings and lists, "
                + "keeping all of its content and wording. Reply with only the reorganised "
                + "note, no preamble."
        }
    }
}

enum ScratchpadAIRefusal: Error, Equatable {
    case emptyNote
    case padLimitReached
    case emptyReply
    case saveFailed

    func message(strings: ScratchpadAIStrings) -> String {
        switch self {
        case .emptyNote: return strings.emptyNote
        case .padLimitReached: return strings.padLimitReached
        case .emptyReply: return strings.emptyReply
        case .saveFailed: return strings.saveFailed
        }
    }
}

enum ScratchpadAIResult {
    /// Checked before anything is sent, so a request that could never be
    /// written back is never spent.
    static func refusalBeforeSending(_ document: ScratchpadDocument) -> ScratchpadAIRefusal? {
        let text = document.pads.first(where: { $0.id == document.selectedID })?.text ?? ""
        if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return .emptyNote }
        if document.pads.count >= ScratchpadDocument.maximumPadCount { return .padLimitReached }
        return nil
    }

    /// The only way an answer reaches the Scratchpad: appended as a new tab.
    /// Takes the document as it is *now*, not as it was when the request
    /// started, so edits made while the answer was on its way survive.
    static func adding(reply: String,
                       for action: ScratchpadAIAction,
                       to document: ScratchpadDocument,
                       strings: ScratchpadAIStrings,
                       now: Date,
                       id: UUID = UUID()) -> Result<ScratchpadDocument, ScratchpadAIRefusal> {
        let text = reply.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return .failure(.emptyReply) }
        guard let next = document.addingPad(defaultName: action.padName(strings: strings),
                                            text: text, modifiedAt: now, id: id)
        else { return .failure(.padLimitReached) }
        return .success(next)
    }
}
