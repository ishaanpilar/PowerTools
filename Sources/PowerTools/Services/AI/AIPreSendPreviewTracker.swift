// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 PowerTools AI contributors

import Foundation

/// Tracks which (content type, provider) combinations have already shown the
/// pre-send preview, so it appears once per combination rather than on every
/// request - roadmap 2.7's "pre-send preview built from it on the first send
/// of each content type". Not a consent record: switching providers, or a
/// restored Mac (`SettingsBackupSupport.machineStateKeys` excludes this key),
/// shows the preview again.
enum AIPreSendPreviewTracker {
    static func hasShownPreview(contentType: String, providerID: String, defaults: UserDefaults = .standard) -> Bool {
        shownKeys(defaults).contains(key(contentType, providerID))
    }

    static func recordPreviewShown(contentType: String, providerID: String, defaults: UserDefaults = .standard) {
        var keys = shownKeys(defaults)
        guard keys.insert(key(contentType, providerID)).inserted else { return }
        defaults.set(Array(keys).sorted(), forKey: DefaultsKey.aiPreSendPreviewShown)
    }

    /// Test-only: lets a provider/content-type combination be previewed
    /// again, e.g. after a test that recorded one.
    static func reset(contentType: String, providerID: String, defaults: UserDefaults = .standard) {
        var keys = shownKeys(defaults)
        keys.remove(key(contentType, providerID))
        defaults.set(Array(keys).sorted(), forKey: DefaultsKey.aiPreSendPreviewShown)
    }

    private static func key(_ contentType: String, _ providerID: String) -> String {
        "\(contentType)::\(providerID)"
    }

    private static func shownKeys(_ defaults: UserDefaults) -> Set<String> {
        Set(defaults.stringArray(forKey: DefaultsKey.aiPreSendPreviewShown) ?? [])
    }
}
