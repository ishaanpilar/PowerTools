// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 PowerTools AI contributors

import Foundation
import Security

/// One provider's API key, in the Keychain only. Never written to
/// UserDefaults, never read by the settings export/import path, and never
/// logged - `CONTRIBUTING.md`'s rule for credentials, and roadmap slice 2.4.
///
/// Mirrors the shape of `CommandBarQueryHabits`' installation key: raw
/// `Security` calls behind an injectable store, so a test can round-trip a
/// key without ever touching the real Keychain.
enum AIProviderCredentials {
    static func key(for providerID: String, using store: AIProviderKeyStore = liveStore) -> String? {
        let (status, data) = store.read(providerID)
        guard status == errSecSuccess, let data, let key = String(data: data, encoding: .utf8),
              !key.isEmpty
        else { return nil }
        return key
    }

    /// Upsert: adds the key if none is stored yet, updates it otherwise.
    @discardableResult
    static func setKey(_ key: String, for providerID: String, using store: AIProviderKeyStore = liveStore) -> Bool {
        guard !key.isEmpty, let data = key.data(using: .utf8) else { return false }
        let updateStatus = store.update(providerID, data)
        if updateStatus == errSecItemNotFound {
            return store.add(providerID, data) == errSecSuccess
        }
        return updateStatus == errSecSuccess
    }

    @discardableResult
    static func removeKey(for providerID: String, using store: AIProviderKeyStore = liveStore) -> Bool {
        let status = store.delete(providerID)
        return status == errSecSuccess || status == errSecItemNotFound
    }

    private static let service = AIProviderCredentials.keyService(
        bundleID: Bundle.main.bundleIdentifier ?? "com.powertools.utils")

    // Developer and official installations must never share or delete each
    // other's keys, the same reasoning `CommandBarQueryHabits` uses for its
    // own Keychain item.
    static func keyService(bundleID: String) -> String {
        bundleID + ".ai-provider-key"
    }

    static let liveStore = AIProviderKeyStore(
        read: { account in
            let query: [CFString: Any] = [
                kSecClass: kSecClassGenericPassword,
                kSecAttrService: service,
                kSecAttrAccount: account,
                kSecReturnData: true,
                kSecMatchLimit: kSecMatchLimitOne,
            ]
            var item: CFTypeRef?
            let status = SecItemCopyMatching(query as CFDictionary, &item)
            return (status, item as? Data)
        },
        add: { account, data in
            SecItemAdd([
                kSecClass: kSecClassGenericPassword,
                kSecAttrService: service,
                kSecAttrAccount: account,
                kSecAttrAccessible: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
                kSecValueData: data,
            ] as CFDictionary, nil)
        },
        update: { account, data in
            let identity: [CFString: Any] = [
                kSecClass: kSecClassGenericPassword,
                kSecAttrService: service,
                kSecAttrAccount: account,
            ]
            return SecItemUpdate(identity as CFDictionary, [kSecValueData: data] as CFDictionary)
        },
        delete: { account in
            SecItemDelete([
                kSecClass: kSecClassGenericPassword,
                kSecAttrService: service,
                kSecAttrAccount: account,
            ] as CFDictionary)
        })
}

/// Injectable so tests can round-trip a key in memory instead of the real
/// Keychain. `account` is the provider id (e.g. "deepseek", "anthropic").
struct AIProviderKeyStore {
    let read: (_ account: String) -> (OSStatus, Data?)
    let add: (_ account: String, _ data: Data) -> OSStatus
    let update: (_ account: String, _ data: Data) -> OSStatus
    let delete: (_ account: String) -> OSStatus
}
