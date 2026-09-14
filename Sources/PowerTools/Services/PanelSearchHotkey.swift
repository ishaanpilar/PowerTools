// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint
// Copyright (C) 2026 PowerTools contributors

import Combine
import Foundation

/// The global shortcut that opens the menu bar panel with its feature search
/// focused. The search belongs to the panel rather than to one feature, so it
/// holds its own key instead of a feature's shortcut role.
final class PanelSearchHotkey: ObservableObject {
    static let shared = PanelSearchHotkey()

    @Published private(set) var registrationFailed = false
    private let hotkey = QuickToolHotkey(id: 40)

    private init() {
        hotkey.onPress = { appDelegate()?.showPanelSearch() }
    }

    var shortcut: GlobalShortcut {
        GlobalShortcut.saved(for: DefaultsKey.panelSearchShortcut, fallback: .panelSearchDefault)
    }

    func syncWithPreferences() {
        let enabled = UserDefaults.standard.bool(forKey: DefaultsKey.panelSearchShortcutEnabled)
        registrationFailed = !hotkey.sync(enabled: enabled, shortcut: shortcut)
    }
}
