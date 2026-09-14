// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 PowerTools AI contributors

import SwiftUI

/// Placeholder page for the AI Text Actions feature (M2). Installing the
/// feature loads no model and makes no connection: this page only exists so
/// the feature has somewhere to live in the hub before the real work lands.
struct AITextActionsSettings: View {
    @ObservedObject private var l10n = L10n.shared
    private var strings: AITextActionsFeatureStrings { FeatureStrings.aiTextActions(l10n.language) }

    var body: some View {
        Form {
            Section {
                Text(strings.settingsIntro)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            Section {
                Label(strings.comingSoonTitle, systemImage: "hourglass")
                    .font(.callout.weight(.medium))
                Text(strings.comingSoonBody)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }
}
