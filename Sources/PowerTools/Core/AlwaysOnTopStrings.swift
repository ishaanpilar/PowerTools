// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint
// Copyright (C) 2026 PowerTools contributors

import Foundation

/// Localized strings for Always On Top. English only for now (roadmap D5);
/// every other language repeats the English text until translation resumes.
struct AlwaysOnTopStrings {
    let title: String
    let caption: String
    let shortcutLabel: String
    let pinnedSectionTitle: String
    let pinnedEmptyText: String
    let hudPinned: String
    let hudUnpinned: String
}

extension FeatureStrings {
    static func alwaysOnTop(_ language: AppLanguage) -> AlwaysOnTopStrings {
        switch language {
        case .enUS: return .enUS
        case .ptBR: return .enUS
        case .tr: return .enUS
        case .ru: return .enUS
        case .es: return .enUS
        case .de: return .enUS
        case .fr: return .enUS
        case .it: return .enUS
        case .ja: return .enUS
        case .ko: return .enUS
        case .zhHans: return .enUS
        case .zhTW: return .enUS
        case .zhHK: return .enUS
        }
    }
}

extension AlwaysOnTopStrings {
    static let enUS = AlwaysOnTopStrings(
        title: "Always On Top",
        caption: "Pin the focused window above every other window with a shortcut, until you unpin it or close it.",
        shortcutLabel: "Pin focused window",
        pinnedSectionTitle: "Pinned windows",
        pinnedEmptyText: "No windows are pinned right now.",
        hudPinned: "Pinned on top",
        hudUnpinned: "Unpinned"
    )
}
