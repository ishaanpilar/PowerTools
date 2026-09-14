// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 PowerTools AI contributors

import Foundation

/// Localized strings for AI text actions. English only for now (roadmap D5);
/// every other language repeats the English text until translation resumes.
struct AITextActionsFeatureStrings {
    let pageTitle: String
    let hubDescription: String
    let settingsIntro: String
    let comingSoonTitle: String
    let comingSoonBody: String
}

extension FeatureStrings {
    static func aiTextActions(_ language: AppLanguage) -> AITextActionsFeatureStrings {
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

extension AITextActionsFeatureStrings {
    static let enUS = AITextActionsFeatureStrings(
        pageTitle: "AI text actions",
        hubDescription: "Rewrite, shorten or translate the text you select, on this Mac or with a provider you choose",
        settingsIntro: "Select text anywhere and rewrite, shorten, proofread, summarise or translate it from the Command Bar. Nothing is sent anywhere until you choose a provider.",
        comingSoonTitle: "Not built yet",
        comingSoonBody: "This page is a placeholder. Installing this feature loads nothing and makes no connection until the text actions themselves ship."
    )
}
