// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 PowerTools AI contributors

import Foundation

/// One Claude Code login. Claude Code keeps it in two halves that must move
/// together: the OAuth tokens in the Keychain item `Claude Code-credentials`,
/// and the identity under `oauthAccount` in `~/.claude.json`. Both are kept
/// as opaque bytes, so fields a later Claude Code adds survive a switch.
struct ClaudeLogin: Codable, Equatable {
    let credentials: Data
    /// The `oauthAccount` object, serialized as JSON.
    let account: Data

    var identity: ClaudeAccountIdentity? { ClaudeAccountIdentity(accountJSON: account) }
}

struct ClaudeAccountIdentity: Equatable {
    let accountID: String
    let email: String
    let organizationID: String
    let organizationName: String

    /// The same person in two organizations has two logins, so the key
    /// includes both.
    var key: String { accountID + ":" + organizationID }

    init?(accountJSON: Data) {
        guard let object = try? JSONSerialization.jsonObject(with: accountJSON) as? [String: Any],
              let accountID = object["accountUuid"] as? String, !accountID.isEmpty
        else { return nil }
        self.accountID = accountID
        email = object["emailAddress"] as? String ?? ""
        organizationID = object["organizationUuid"] as? String ?? ""
        organizationName = object["organizationName"] as? String ?? ""
    }
}

/// The login Claude Code will use the next time it starts.
struct ClaudeLiveLoginStore {
    let readCredentials: () -> Data?
    let writeCredentials: (Data) -> Bool
    let readAccount: () -> Data?
    let writeAccount: (Data) -> Bool
}

/// Logins PowerTools keeps for switching back, keyed by identity.
struct ClaudeSavedLoginStore {
    let all: () -> [ClaudeLogin]
    let save: (_ key: String, _ login: ClaudeLogin) -> Bool
    let remove: (_ key: String) -> Bool
}

enum ClaudeAccountSwitchResult: Equatable {
    case switched
    case alreadyActive
    case notSaved
    /// Tokens are present but `~/.claude.json` names no account, so the live
    /// login cannot be saved and a switch would lose it.
    case liveLoginUnidentified
    case saveFailed
    case credentialWriteFailed
    case accountWriteFailed
}

enum ClaudeAccountSwitching {
    static func currentLogin(_ live: ClaudeLiveLoginStore) -> ClaudeLogin? {
        guard let credentials = live.readCredentials(), let account = live.readAccount() else { return nil }
        return ClaudeLogin(credentials: credentials, account: account)
    }

    /// Saves the live login, replacing an older copy of the same account.
    /// Claude Code rotates the refresh token as it uses it, so a copy that is
    /// not refreshed this way stops working after its first restore.
    static func saveCurrent(live: ClaudeLiveLoginStore, saved: ClaudeSavedLoginStore) -> ClaudeAccountIdentity? {
        guard let login = currentLogin(live), let identity = login.identity,
              saved.save(identity.key, login)
        else { return nil }
        return identity
    }

    static func switchTo(_ key: String,
                         live: ClaudeLiveLoginStore,
                         saved: ClaudeSavedLoginStore) -> ClaudeAccountSwitchResult {
        guard let target = saved.all().first(where: { $0.identity?.key == key }),
              let targetIdentity = target.identity
        else { return .notSaved }

        let previousCredentials = live.readCredentials()
        if let previousCredentials {
            guard let account = live.readAccount(),
                  let identity = ClaudeAccountIdentity(accountJSON: account)
            else { return .liveLoginUnidentified }
            let current = ClaudeLogin(credentials: previousCredentials, account: account)
            if identity.key == key {
                return saved.save(key, current) ? .alreadyActive : .saveFailed
            }
            guard saved.save(identity.key, current) else { return .saveFailed }
        }

        guard live.writeCredentials(target.credentials),
              live.readCredentials() == target.credentials
        else {
            restore(previousCredentials, live)
            return .credentialWriteFailed
        }
        guard live.writeAccount(target.account),
              live.readAccount().flatMap(ClaudeAccountIdentity.init(accountJSON:)) == targetIdentity
        else {
            restore(previousCredentials, live)
            return .accountWriteFailed
        }
        return .switched
    }

    private static func restore(_ credentials: Data?, _ live: ClaudeLiveLoginStore) {
        if let credentials { _ = live.writeCredentials(credentials) }
    }
}

/// Reading and rewriting `oauthAccount` in Claude Code's config file, leaving
/// every other key as it was.
enum ClaudeConfigFile {
    static func account(in config: Data) -> Data? {
        guard let object = try? JSONSerialization.jsonObject(with: config) as? [String: Any],
              let account = object["oauthAccount"] as? [String: Any]
        else { return nil }
        return try? JSONSerialization.data(withJSONObject: account)
    }

    static func replacingAccount(in config: Data, with account: Data) -> Data? {
        guard var object = try? JSONSerialization.jsonObject(with: config) as? [String: Any],
              let accountObject = try? JSONSerialization.jsonObject(with: account) as? [String: Any]
        else { return nil }
        object["oauthAccount"] = accountObject
        return try? JSONSerialization.data(withJSONObject: object,
                                           options: [.prettyPrinted, .withoutEscapingSlashes])
    }
}

/// `/usr/bin/security` is how Claude Code itself reads and writes its
/// Keychain item, so going through it keeps that item's access list as Claude
/// Code expects and raises no Keychain prompt.
enum ClaudeKeychainCommand {
    static let service = "Claude Code-credentials"

    /// The `acct` attribute from `security find-generic-password` output.
    static func accountAttribute(in output: String) -> String? {
        let marker = "\"acct\"<blob>=\""
        guard let line = output.split(separator: "\n").first(where: { $0.contains(marker) }),
              let start = line.range(of: marker)?.upperBound,
              let end = line[start...].lastIndex(of: "\"")
        else { return nil }
        return String(line[start..<end])
    }

    /// One `security -i` line. The secret travels as hex on standard input,
    /// never as an argument another process could read from the process list.
    static func writeCommand(account: String, credentials: Data) -> String? {
        guard !account.isEmpty,
              !account.contains(where: { $0 == "\"" || $0 == "\\" || $0.isNewline })
        else { return nil }
        let hex = credentials.map { String(format: "%02x", $0) }.joined()
        return "add-generic-password -U -a \"\(account)\" -s \"\(service)\" -X \(hex)\n"
    }
}

