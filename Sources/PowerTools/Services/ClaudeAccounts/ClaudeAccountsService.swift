// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 PowerTools AI contributors

import Foundation
import Security

/// Saved Claude Code logins and the one Claude Code will use next. A switch
/// reaches only `claude` sessions started after it; running ones keep the
/// login they loaded.
final class ClaudeAccountsService: ObservableObject {
    static let shared = ClaudeAccountsService()

    @Published private(set) var accounts: [ClaudeAccountIdentity] = []
    @Published private(set) var activeKey: String?
    @Published private(set) var isWorking = false

    private let queue = DispatchQueue(label: "PowerTools.ClaudeAccounts")
    private let live: ClaudeLiveLoginStore
    private let saved: ClaudeSavedLoginStore

    init(live: ClaudeLiveLoginStore = ClaudeAccountStores.live,
         saved: ClaudeSavedLoginStore = ClaudeAccountStores.saved) {
        self.live = live
        self.saved = saved
    }

    /// Also refreshes the active account's saved copy, so a login renewed in
    /// Terminal is kept without a separate save.
    func refresh() {
        perform { ClaudeAccountSwitching.syncActive(live: $0, saved: $1) }
    }

    func saveCurrent(completion: @escaping (ClaudeAccountIdentity?) -> Void = { _ in }) {
        perform({ ClaudeAccountSwitching.saveCurrent(live: $0, saved: $1) }, completion: completion)
    }

    func switchTo(_ key: String, completion: @escaping (ClaudeAccountSwitchResult) -> Void = { _ in }) {
        perform({ ClaudeAccountSwitching.switchTo(key, live: $0, saved: $1) }, completion: completion)
    }

    /// Logging in replaces Claude Code's current login, so that login is saved
    /// first. Terminal then runs Claude Code's own login for the person.
    func logIn(email: String?, completion: @escaping (_ opened: Bool) -> Void = { _ in }) {
        perform({ ClaudeAccountSwitching.saveCurrent(live: $0, saved: $1) }) { _ in
            completion(AppleScriptRunner.openInTerminal(ClaudeLoginCommand.command(email: email)).ok)
        }
    }

    func remove(_ key: String) {
        perform { _, saved in _ = saved.remove(key) }
    }

    /// Keychain and file work runs off the main thread, one operation at a
    /// time, and every operation ends by re-reading both stores.
    private func perform<T>(_ work: @escaping (ClaudeLiveLoginStore, ClaudeSavedLoginStore) -> T,
                            completion: @escaping (T) -> Void = { _ in }) {
        isWorking = true
        queue.async { [live, saved] in
            let result = work(live, saved)
            let accounts = saved.all().compactMap(\.identity)
                .sorted { ($0.email, $0.organizationName) < ($1.email, $1.organizationName) }
            let activeKey = live.readAccount().flatMap(ClaudeAccountIdentity.init(accountJSON:))?.key
            DispatchQueue.main.async {
                self.accounts = accounts
                self.activeKey = activeKey
                self.isWorking = false
                completion(result)
            }
        }
    }
}

enum ClaudeAccountStores {
    private static let security = "/usr/bin/security"

    private static func runSecurity(_ arguments: [String], input: Data? = nil) -> BoundedProcessRunner.Result {
        BoundedProcessRunner.run(security, arguments, input: input, timeout: 10, maxOutputBytes: 64 * 1024)
    }

    /// Claude Code's config file, through a dotfiles symlink if there is one,
    /// so an atomic rewrite replaces the file and not the link.
    private static var configURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".claude.json").resolvingSymlinksInPath()
    }

    static let live = ClaudeLiveLoginStore(
        readCredentials: {
            let result = runSecurity(["find-generic-password", "-s", ClaudeKeychainCommand.service, "-w"])
            guard result.status == 0 else { return nil }
            var output = result.output
            if output.last == UInt8(ascii: "\n") { output.removeLast() }
            return output.isEmpty ? nil : output
        },
        writeCredentials: { credentials in
            // Update the item Claude Code made under its own account name, so
            // `-U` replaces it instead of adding a second item beside it.
            let attributes = runSecurity(["find-generic-password", "-s", ClaudeKeychainCommand.service])
            let account = attributes.status == 0
                ? ClaudeKeychainCommand.accountAttribute(in: String(decoding: attributes.output, as: UTF8.self))
                : nil
            guard let command = ClaudeKeychainCommand.writeCommand(account: account ?? NSUserName(),
                                                                   credentials: credentials)
            else { return false }
            return runSecurity(["-i"], input: Data(command.utf8)).status == 0
        },
        readAccount: {
            (try? Data(contentsOf: configURL)).flatMap(ClaudeConfigFile.account(in:))
        },
        writeAccount: { account in
            let url = configURL
            guard let original = try? Data(contentsOf: url),
                  let updated = ClaudeConfigFile.replacingAccount(in: original, with: account)
            else { return false }
            let permissions = try? FileManager.default.attributesOfItem(atPath: url.path)[.posixPermissions]
            guard (try? updated.write(to: url, options: .atomic)) != nil else { return false }
            if let permissions {
                try? FileManager.default.setAttributes([.posixPermissions: permissions], ofItemAtPath: url.path)
            }
            return true
        })

    // Developer and official installations keep separate saved logins, the
    // same reasoning `AIProviderCredentials` uses for its Keychain item.
    private static let savedService = (Bundle.main.bundleIdentifier ?? "com.powertools.utils") + ".claude-account"

    static let saved = ClaudeSavedLoginStore(
        all: {
            let query: [CFString: Any] = [
                kSecClass: kSecClassGenericPassword,
                kSecAttrService: savedService,
                kSecReturnAttributes: true,
                kSecMatchLimit: kSecMatchLimitAll,
            ]
            var items: CFTypeRef?
            guard SecItemCopyMatching(query as CFDictionary, &items) == errSecSuccess,
                  let attributes = items as? [[CFString: Any]]
            else { return [] }
            return attributes.compactMap { $0[kSecAttrAccount] as? String }.compactMap(savedLogin)
        },
        save: { key, login in
            guard let data = try? JSONEncoder().encode(login) else { return false }
            let identity: [CFString: Any] = [
                kSecClass: kSecClassGenericPassword,
                kSecAttrService: savedService,
                kSecAttrAccount: key,
            ]
            let label = "PowerTools Claude account " + (login.identity?.email ?? key)
            let status = SecItemUpdate(identity as CFDictionary,
                                       [kSecValueData: data, kSecAttrLabel: label] as CFDictionary)
            if status != errSecItemNotFound { return status == errSecSuccess }
            var item = identity
            item[kSecValueData] = data
            item[kSecAttrLabel] = label
            item[kSecAttrAccessible] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
            return SecItemAdd(item as CFDictionary, nil) == errSecSuccess
        },
        remove: { key in
            let status = SecItemDelete([
                kSecClass: kSecClassGenericPassword,
                kSecAttrService: savedService,
                kSecAttrAccount: key,
            ] as CFDictionary)
            return status == errSecSuccess || status == errSecItemNotFound
        })

    private static func savedLogin(_ key: String) -> ClaudeLogin? {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: savedService,
            kSecAttrAccount: key,
            kSecReturnData: true,
            kSecMatchLimit: kSecMatchLimitOne,
        ]
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data
        else { return nil }
        return try? JSONDecoder().decode(ClaudeLogin.self, from: data)
    }
}
