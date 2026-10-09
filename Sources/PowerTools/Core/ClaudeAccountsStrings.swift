// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 PowerTools AI contributors

import Foundation

/// Localized strings for Claude Accounts. English only for now (roadmap D5);
/// every other language repeats the English text until translation resumes.
struct ClaudeAccountsStrings {
    let title: String
    let hubDescription: String
    let panelCaption: String
    let intro: String
    let activeBadge: String
    let switchButton: String
    let saveCurrentButton: String
    let removeHelp: String
    let removeConfirmTitleFormat: String
    let removeConfirmMessage: String
    let removeConfirmAction: String
    let emptyText: String
    let addAccountHint: String
    let logInButton: String
    let logInAgainHelp: String
    let loginOpened: String
    let terminalFailed: String
    let savedFormat: String
    let nothingToSave: String
    let switchedFormat: String
    let alreadyActive: String
    let notSaved: String
    let liveLoginUnidentified: String
    let saveFailed: String
    let credentialWriteFailed: String
    let accountWriteFailed: String

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
        intro: "A switch applies to Claude Code sessions you start afterwards. Sessions already running keep their account. A token in CLAUDE_CODE_OAUTH_TOKEN overrides any switch.",
        activeBadge: "Active",
        switchButton: "Switch",
        saveCurrentButton: "Save Current Login",
        removeHelp: "Remove this saved login",
        removeConfirmTitleFormat: "Remove the saved login for %@?",
        removeConfirmMessage: "PowerTools forgets its copy of this login. Claude Code itself is not logged out.",
        removeConfirmAction: "Remove",
        emptyText: "No saved logins yet. Log in with claude in Terminal, then save the login here.",
        addAccountHint: "Logging in replaces Claude Code’s current login, so PowerTools saves that login first.",
        logInButton: "Log In…",
        logInAgainHelp: "Log in to this account again",
        loginOpened: "Finish in Terminal: open or copy the link it shows, sign in, and paste the code back. A renewed login is saved when you reopen this list. Save a new account with Save Current Login.",
        terminalFailed: "Terminal couldn’t be opened. Allow PowerTools AI to control Terminal in System Settings › Privacy & Security › Automation.",
        savedFormat: "Saved the login for %@.",
        nothingToSave: "Claude Code has no login on this Mac to save.",
        switchedFormat: "Switched to %@. New Claude Code sessions use this account.",
        alreadyActive: "That account is already active. Its saved login was refreshed.",
        notSaved: "That login is no longer saved.",
        liveLoginUnidentified: "Claude Code’s current login has no account details, so it can’t be saved. Nothing was changed.",
        saveFailed: "The current login couldn’t be saved, so nothing was changed.",
        credentialWriteFailed: "Claude Code’s Keychain item couldn’t be updated, so the switch was stopped.",
        accountWriteFailed: "~/.claude.json couldn’t be updated, so PowerTools put the previous Keychain login back. Run claude auth status to check."
    )
}
