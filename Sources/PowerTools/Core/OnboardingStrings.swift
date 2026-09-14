// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint
// Copyright (C) 2026 PowerTools contributors

import Foundation

/// Strings for the setup flow. English first: until translations resume,
/// every language returns the English catalog.
struct OnboardingStrings {
    let stepFormat: String
    let setupTitle: String
    let chooseMyself: String
    let selectedCountFormat: String
    let permissionsTitle: String
    let permissionsBody: String
    let permissionsNoneTitle: String
    let permissionUsedByFormat: String
    let aiTitle: String
    let aiComingSoon: String
    let aiBody: String
    let aiTextTitle: String
    let aiTextBody: String
    let aiAskTitle: String
    let aiAskBody: String
    let aiExplainTitle: String
    let aiExplainBody: String
    let aiWhereTitle: String
    let aiWhereBody: String
    let aiChoiceTitle: String
    let aiChoiceBody: String
    let doneTitle: String
    let doneBody: String
    let doneInstalledFormat: String
    let doneFindTitle: String
    let openAppFormat: String
}

extension FeatureStrings {
    static func onboarding(_ language: AppLanguage) -> OnboardingStrings {
        switch language {
        case .enUS, .ptBR, .tr, .ru, .es, .de, .fr, .it, .ja, .ko, .zhHans, .zhTW, .zhHK:
            return .enUS
        }
    }
}

extension OnboardingStrings {
    static let enUS = OnboardingStrings(
        stepFormat: "Step %1$d of %2$d",
        setupTitle: "Choose your tools",
        chooseMyself: "Choose myself",
        selectedCountFormat: "%d selected",
        permissionsTitle: "Give it the access it needs",
        permissionsBody: "Only what the features you chose use. Every permission is optional, and you can change it later in System Settings.",
        permissionsNoneTitle: "You’re good to go",
        permissionUsedByFormat: "Used by %@",
        aiTitle: "AI features",
        aiComingSoon: "Coming soon",
        aiBody: "Optional AI that helps you get more from these tools. It isn’t available yet, and nothing here turns anything on.",
        aiTextTitle: "Text actions",
        aiTextBody: "Rewrite, shorten, proofread, summarise or translate the text you select.",
        aiAskTitle: "Ask in plain words",
        aiAskBody: "Describe what you want, then review a plan before any step runs.",
        aiExplainTitle: "Explain your Mac",
        aiExplainBody: "Answers to “Why is my Mac busy?” from your own system readings.",
        aiWhereTitle: "Where it will run",
        aiWhereBody: "On this Mac with Apple Intelligence on macOS 26 or later, or with a cloud provider using your own API key.",
        aiChoiceTitle: "Your choice",
        aiChoiceBody: "Off until you turn it on. Before anything is sent to a cloud provider, you’ll see exactly what and where.",
        doneTitle: "All set!",
        doneBody: "It’s running in your menu bar, ready when you are.",
        doneInstalledFormat: "%d features installed",
        doneFindTitle: "Find it in your menu bar",
        openAppFormat: "Open %@"
    )
}
