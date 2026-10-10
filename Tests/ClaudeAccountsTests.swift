// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 PowerTools AI contributors

import Foundation

enum ClaudeAccountsTests {
    static func run(_ suite: TestSuite) {
        identityChecks(suite)
        switchChecks(suite)
        failureChecks(suite)
        configFileChecks(suite)
        keychainCommandChecks(suite)
        processInputChecks(suite)
    }

    private static func account(_ id: String, org: String = "org-1", email: String? = nil) -> Data {
        try! JSONSerialization.data(withJSONObject: [
            "accountUuid": id, "organizationUuid": org,
            "emailAddress": email ?? "\(id)@example.com", "organizationName": org,
        ])
    }

    private static func login(_ id: String, token: String, org: String = "org-1") -> ClaudeLogin {
        ClaudeLogin(credentials: Data(token.utf8), account: account(id, org: org))
    }

    /// In-memory stand-ins for Claude Code's Keychain item and config file
    /// and for PowerTools' saved copies.
    private final class Fixture {
        var credentials: Data?
        var account: Data?
        var savedLogins: [String: ClaudeLogin] = [:]
        var rejectCredentialWrites = false
        var dropCredentialWrites = false
        var rejectAccountWrites = false

        init(live: ClaudeLogin?, saved: [ClaudeLogin]) {
            credentials = live?.credentials
            account = live?.account
            for login in saved { savedLogins[login.identity!.key] = login }
        }

        var live: ClaudeLiveLoginStore {
            ClaudeLiveLoginStore(
                readCredentials: { self.credentials },
                writeCredentials: { data in
                    if self.rejectCredentialWrites { return false }
                    if !self.dropCredentialWrites { self.credentials = data }
                    return true
                },
                readAccount: { self.account },
                writeAccount: { data in
                    if self.rejectAccountWrites { return false }
                    self.account = data
                    return true
                })
        }

        var saved: ClaudeSavedLoginStore {
            ClaudeSavedLoginStore(
                all: { Array(self.savedLogins.values) },
                save: { key, login in self.savedLogins[key] = login; return true },
                remove: { key in self.savedLogins[key] = nil; return true })
        }

        func switchTo(_ key: String) -> ClaudeAccountSwitchResult {
            ClaudeAccountSwitching.switchTo(key, live: live, saved: saved)
        }
    }

    private static func identityChecks(_ suite: TestSuite) {
        let first = ClaudeAccountIdentity(accountJSON: account("a", org: "org-1"))
        let second = ClaudeAccountIdentity(accountJSON: account("a", org: "org-2"))
        suite.expect(first?.email == "a@example.com", "a login's identity reads the account email")
        suite.expect(first != nil && second != nil && first?.key != second?.key,
                     "one person in two organizations is saved as two logins")
        suite.expect(ClaudeAccountIdentity(accountJSON: Data("{}".utf8)) == nil,
                     "an account object without an account id names no login")
    }

    private static func switchChecks(_ suite: TestSuite) {
        let staleA = login("a", token: "a-old")
        let b = login("b", token: "b-token")
        let fixture = Fixture(live: login("a", token: "a-rotated"), saved: [staleA, b])
        let keyA = staleA.identity!.key, keyB = b.identity!.key

        suite.expect(fixture.switchTo(keyB) == .switched, "switching to a saved login succeeds")
        suite.expect(fixture.credentials == b.credentials && fixture.account == b.account,
                     "a switch installs both the tokens and the account of the chosen login")
        suite.expect(fixture.savedLogins[keyA]?.credentials == Data("a-rotated".utf8),
                     "a switch first saves the outgoing login's latest tokens, not its stale copy")

        suite.expect(fixture.switchTo(keyB) == .alreadyActive, "switching to the active login does nothing")
        fixture.credentials = Data("b-rotated".utf8)
        _ = fixture.switchTo(keyB)
        suite.expect(fixture.savedLogins[keyB]?.credentials == Data("b-rotated".utf8),
                     "choosing the active login still refreshes its saved copy")

        let unsaved = Fixture(live: login("c", token: "c-token"), saved: [b])
        suite.expect(unsaved.switchTo(keyB) == .switched
                         && unsaved.savedLogins[login("c", token: "").identity!.key]?.credentials == Data("c-token".utf8),
                     "switching away from a login that was never saved keeps it")

        let loggedOut = Fixture(live: nil, saved: [b])
        suite.expect(loggedOut.switchTo(keyB) == .switched && loggedOut.credentials == b.credentials,
                     "a switch works when Claude Code is logged out")

        let current = Fixture(live: login("d", token: "d-token"), saved: [])
        let saved = ClaudeAccountSwitching.saveCurrent(live: current.live, saved: current.saved)
        suite.expect(saved?.accountID == "d" && current.savedLogins[saved!.key]?.credentials == Data("d-token".utf8),
                     "saving the current login stores it under its identity")
    }

    private static func failureChecks(_ suite: TestSuite) {
        let a = login("a", token: "a-token")
        let b = login("b", token: "b-token")
        let keyB = b.identity!.key

        let missing = Fixture(live: a, saved: [a])
        suite.expect(missing.switchTo("nobody:org") == .notSaved && missing.credentials == a.credentials,
                     "an unknown login leaves Claude Code untouched")

        let unidentified = Fixture(live: a, saved: [b])
        unidentified.account = nil
        suite.expect(unidentified.switchTo(keyB) == .liveLoginUnidentified
                         && unidentified.credentials == a.credentials,
                     "tokens with no account are never overwritten, since they cannot be saved first")

        let rejected = Fixture(live: a, saved: [b])
        rejected.rejectCredentialWrites = true
        suite.expect(rejected.switchTo(keyB) == .credentialWriteFailed && rejected.account == a.account,
                     "a refused Keychain write stops the switch before the account changes")

        let dropped = Fixture(live: a, saved: [b])
        dropped.dropCredentialWrites = true
        suite.expect(dropped.switchTo(keyB) == .credentialWriteFailed && dropped.account == a.account,
                     "a Keychain write that reports success but does not read back fails the switch")

        let accountFails = Fixture(live: a, saved: [b])
        accountFails.rejectAccountWrites = true
        suite.expect(accountFails.switchTo(keyB) == .accountWriteFailed
                         && accountFails.credentials == a.credentials,
                     "a failed account write puts the previous tokens back")
    }

    private static func configFileChecks(_ suite: TestSuite) {
        let config = try! JSONSerialization.data(withJSONObject: [
            "numStartups": 42, "projects": ["/tmp/x": ["allowedTools": ["Bash"]]],
            "oauthAccount": try! JSONSerialization.jsonObject(with: account("a")),
        ])
        let replaced = ClaudeConfigFile.replacingAccount(in: config, with: account("b"))
        let object = replaced.flatMap { try? JSONSerialization.jsonObject(with: $0) as? NSDictionary }
        let original = try! JSONSerialization.jsonObject(with: config) as! NSDictionary
        suite.expect(original.allKeys.allSatisfy { key in
                         (key as? String) == "oauthAccount" || object?[key].map { ($0 as AnyObject).isEqual(original[key]) } == true
                     },
                     "replacing the account keeps every other key of Claude Code's config")
        suite.expect(replaced.flatMap(ClaudeConfigFile.account(in:)).flatMap(ClaudeAccountIdentity.init(accountJSON:))
                         == ClaudeAccountIdentity(accountJSON: account("b")),
                     "the config file names the new account after a replace")
        suite.expect(ClaudeConfigFile.replacingAccount(in: Data("not json".utf8), with: account("b")) == nil,
                     "an unreadable config file is never overwritten")
    }

    private static func keychainCommandChecks(_ suite: TestSuite) {
        let user = "someone"
        let output = """
        keychain: "/Users/\(user)/Library/Keychains/login.keychain-db"
        attributes:
            "acct"<blob>="\(user)"
            "svce"<blob>="\(ClaudeKeychainCommand.service)"
        """
        suite.expect(ClaudeKeychainCommand.accountAttribute(in: output) == user,
                     "the Keychain item's account name is read from security's attribute listing")

        let secret = Data(#"{"claudeAiOauth":{"accessToken":"x y \"z\""}}"#.utf8)
        let command = ClaudeKeychainCommand.writeCommand(account: user, credentials: secret)
        let hex = command?.split(separator: " ").last?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let decoded = Data(stride(from: 0, to: hex.count, by: 2).compactMap { offset -> UInt8? in
            let start = hex.index(hex.startIndex, offsetBy: offset)
            return UInt8(hex[start..<hex.index(start, offsetBy: 2)], radix: 16)
        })
        suite.expect(decoded == secret, "the written secret is the exact credential bytes, hex encoded")
        suite.expect(command.map { !$0.contains("accessToken") } == true,
                     "the secret never appears in readable form in the command")
        suite.expect(ClaudeKeychainCommand.writeCommand(account: "a\" -s other", credentials: secret) == nil,
                     "an account name that could break out of its quotes is refused")
    }

    private static func processInputChecks(_ suite: TestSuite) {
        let input = Data("standard input reaches the child\n".utf8)
        let echoed = BoundedProcessRunner.run("/bin/cat", [], input: input, timeout: 5, maxOutputBytes: 1024)
        suite.expect(echoed.status == 0 && echoed.output == input, "a process receives its standard input")

        let oversized = Data(count: BoundedProcessRunner.maxInputBytes + 1)
        let refused = BoundedProcessRunner.run("/bin/cat", [], input: oversized, timeout: 5, maxOutputBytes: 1024)
        suite.expect(refused.status == -1 && refused.output.isEmpty,
                     "input larger than the pipe buffer is refused instead of blocking")
    }





}
