// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint
// Copyright (C) 2026 PowerTools contributors

import SwiftUI

struct AlwaysOnTopSettings: View {
    @ObservedObject private var l10n = L10n.shared
    @ObservedObject private var permissions = Permissions.shared
    @ObservedObject private var service = AlwaysOnTopService.shared
    @AppStorage(DefaultsKey.alwaysOnTopShortcutEnabled) private var enabled = false

    private var strings: AlwaysOnTopStrings { FeatureStrings.alwaysOnTop(l10n.language) }

    var body: some View {
        Form {
            Section {
                Toggle(l10n.s.quickToolShortcutToggle, isOn: $enabled)
                    .onChange(of: enabled) { _, _ in AlwaysOnTopService.shared.syncWithPreferences() }
                ShortcutPreferenceRow(role: .alwaysOnTop, isEnabled: enabled, label: strings.shortcutLabel) {
                    AlwaysOnTopService.shared.syncWithPreferences()
                }
                if enabled, service.shortcutRegistrationFailed {
                    Text(l10n.s.shortcutUnavailable)
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
                Text(strings.caption)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section(strings.pinnedSectionTitle) {
                if sortedPinnedWindows.isEmpty {
                    Text(strings.pinnedEmptyText)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(sortedPinnedWindows) { pinned in
                        HStack(spacing: 9) {
                            Image(nsImage: pinned.icon)
                                .resizable().frame(width: 20, height: 20)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(pinned.appName)
                                if !pinned.windowTitle.isEmpty {
                                    Text(pinned.windowTitle)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            Spacer()
                            Button {
                                service.unpin(pinned.id)
                            } label: {
                                Image(systemName: "minus.circle.fill")
                                    .foregroundStyle(.secondary)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }

            if enabled, !permissions.accessibility {
                Section(l10n.s.permissionRequired) {
                    PermissionRow(kind: .accessibility)
                }
            }
        }
        .formStyle(.grouped)
    }

    private var sortedPinnedWindows: [AlwaysOnTopService.PinnedWindowInfo] {
        Array(service.pinnedWindows.values).sorted {
            $0.appName.localizedCaseInsensitiveCompare($1.appName) == .orderedAscending
        }
    }
}
