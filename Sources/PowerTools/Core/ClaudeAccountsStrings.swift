// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 PowerTools AI contributors

import Foundation

/// Localized strings for Claude Accounts. English only for now (roadmap D5);
/// every other language repeats the English text until translation resumes.
struct ClaudeAccountsStrings {
    let title: String
    let hubDescription: String
    let panelCaption: String
    let accountsSectionTitle: String
    let accountsFooter: String
    let addSectionTitle: String
    let addFooter: String
    let panelFootnote: String
    let activeBadge: String
    let switchButton: String
    let moreActionsHelp: String
    let logInAgainButton: String
    let removeButton: String
    let saveCurrentButton: String
    let addAccountButton: String
    let emptyTitle: String
    let emptyText: String
    let removeConfirmTitleFormat: String
    let removeConfirmMessage: String
    let removeConfirmAction: String
    let savedFormat: String
    let nothingToSave: String
    let switchedFormat: String
    let alreadyActive: String
    let notSaved: String
    let liveLoginUnidentified: String
    let saveFailed: String
    let credentialWriteFailed: String
    let accountWriteFailed: String
    let loginOpened: String
    let terminalFailed: String

    func message(for result: ClaudeAccountSwitchResult, email: String) -> String {
        switch result {
        case .switched: return String(format: switchedFormat, email)
        case .alreadyActive: return alreadyActive
        case .notSaved: return notSaved
        case .liveLoginUnidentified: return liveLoginUnidentified
        case .saveFailed: return saveFailed
        case .credentialWriteFailed: return credentialWriteFailed
        case .accountWriteFailed: return accountWriteFailed
        }
    }
}

extension FeatureStrings {
    static func claudeAccounts(_ language: AppLanguage) -> ClaudeAccountsStrings {
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

extension ClaudeAccountsStrings {
    static let enUS = ClaudeAccountsStrings(
        title: "Claude Accounts",
        hubDescription: "Save the Claude Code logins on this Mac and switch between them from the menu bar.",
        panelCaption: "Switch the account Claude Code uses",
        accountsSectionTitle: "Accounts",
        accountsFooter: "A switch applies to Claude Code sessions you start afterwards; running sessions keep their account. A token in CLAUDE_CODE_OAUTH_TOKEN overrides any switch.",
        addSectionTitle: "Add an Account",
        addFooter: "Add Account saves the current login, then opens Terminal to sign in. Copy the link it shows, sign in, and paste the code back, then choose Save Current Login.",
        panelFootnote: "Applies to Claude Code sessions you start next.",
        activeBadge: "Active",
        switchButton: "Switch",
        moreActionsHelp: "More Actions",
        logInAgainButton: "Log In Again\u{2026}",
        removeButton: "Remove\u{2026}",
        saveCurrentButton: "Save Current Login",
        addAccountButton: "Add Account\u{2026}",
        emptyTitle: "No saved accounts",
        emptyText: "Save the login Claude Code is using now, so you can switch back to it later.",
        removeConfirmTitleFormat: "Remove the saved login for %@?",
        removeConfirmMessage: "PowerTools forgets its copy of this login. Claude Code itself is not logged out.",
        removeConfirmAction: "Remove",
        savedFormat: "Saved the login for %@.",
        nothingToSave: "Claude Code has no login on this Mac to save.",
        switchedFormat: "Switched to %@. New Claude Code sessions use this account.",
        alreadyActive: "That account is already active. Its saved login was refreshed.",
        notSaved: "That login is no longer saved.",
        liveLoginUnidentified: "Claude Code\u{2019}s current login has no account details, so it can\u{2019}t be saved. Nothing was changed.",
        saveFailed: "The current login couldn\u{2019}t be saved, so nothing was changed.",
        credentialWriteFailed: "Claude Code\u{2019}s Keychain item couldn\u{2019}t be updated, so the switch was stopped.",
        accountWriteFailed: "~/.claude.json couldn\u{2019}t be updated, so PowerTools put the previous Keychain login back. Run claude auth status to check.",
        loginOpened: "Terminal is open. Copy the link it shows, sign in, and paste the code back. A renewed login is saved when you reopen this list.",
        terminalFailed: "Terminal couldn\u{2019}t be opened. Allow PowerTools AI to control Terminal in System Settings \u{203A} Privacy & Security \u{203A} Automation."
    )
}
