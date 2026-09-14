// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint
// Copyright (C) 2026 PowerTools contributors

import SwiftUI

/// General settings for the shortcut that opens the panel's feature search.
/// It has no feature role, so it records through the same field and checks
/// the same conflicts as `ShortcutPreferenceRow` without being one.
struct PanelSearchShortcutSection: View {
    @ObservedObject private var l10n = L10n.shared
    @ObservedObject private var hotkey = PanelSearchHotkey.shared
    @AppStorage(DefaultsKey.panelSearchShortcutEnabled) private var isEnabled = true
    @AppStorage(DefaultsKey.panelSearchShortcut)
    private var rawValue = GlobalShortcut.panelSearchDefault.storageValue
    @State private var errorText: String?
    @State private var isRecording = false

    var body: some View {
        let strings = FeatureStrings.panelSearch(l10n.language)
        Section(strings.shortcutSection) {
            Toggle(strings.shortcutToggle, isOn: $isEnabled)
                .onChange(of: isEnabled) { _, _ in PanelSearchHotkey.shared.syncWithPreferences() }
            HStack(spacing: 8) {
                Text(strings.shortcutLabel)
                Spacer()
                ShortcutRecorderButton(shortcut: shortcut,
                                       isEnabled: isEnabled,
                                       waitingTitle: l10n.s.shortcutPressKeys,
                                       notCapturedAction: { errorText = l10n.s.shortcutNotCaptured },
                                       recordingChanged: { recording in
                                           isRecording = recording
                                           if recording { errorText = nil }
                                       },
                                       invalidAction: { errorText = l10n.s.shortcutInvalid },
                                       captureAction: save)
                    .frame(width: 108)
                    .disabled(!isEnabled)
                Button(l10n.s.shortcutReset) {
                    rawValue = GlobalShortcut.panelSearchDefault.storageValue
                    errorText = nil
                    PanelSearchHotkey.shared.syncWithPreferences()
                }
                .disabled(!isEnabled || shortcut == .panelSearchDefault)
            }
            if let errorText {
                Text(errorText)
                    .font(.caption)
                    .foregroundStyle(.orange)
            } else if isRecording {
                Text(ShortcutRecordingCaption.text(l10n.s, canClear: false))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else if isEnabled, hotkey.registrationFailed {
                Text(l10n.s.shortcutUnavailable)
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
            Text(strings.shortcutCaption)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .onChange(of: l10n.language) { _, _ in errorText = nil }
    }

    private var shortcut: GlobalShortcut {
        GlobalShortcut(storageValue: rawValue) ?? .panelSearchDefault
    }

    private func save(_ shortcut: GlobalShortcut) {
        if let conflict = GlobalShortcutRole.conflict(for: shortcut, excluding: nil) {
            errorText = String(format: l10n.s.shortcutConflictFormat, conflict.title(l10n.s))
            return
        }
        if shortcut.conflictsWithSystemShortcut(for: nil) {
            errorText = String(format: l10n.s.shortcutConflictFormat, "macOS")
            return
        }
        rawValue = shortcut.storageValue
        errorText = nil
        PanelSearchHotkey.shared.syncWithPreferences()
    }
}
