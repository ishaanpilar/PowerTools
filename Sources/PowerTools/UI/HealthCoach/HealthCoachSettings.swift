// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 PowerTools AI contributors

import SwiftUI

/// Grown across tasks 04-06 (`docs/ai-health-coach/`): the panel header
/// already narrates findings unconditionally whether this feature is
/// installed or not — installing it reveals the controls that already have
/// a real, working effect. Narration mode, limits and the provider choice
/// are later tasks; this page grows into them rather than being replaced.
struct HealthCoachSettings: View {
    @ObservedObject private var l10n = L10n.shared
    @ObservedObject private var journalService = HealthActivityJournalService.shared
    @AppStorage(DefaultsKey.healthCoachMemoryHogPercent) private var memoryHogPercent = 30

    private var strings: HealthCoachStrings { FeatureStrings.healthCoach(l10n.language) }

    var body: some View {
        Form {
            Section {
                Text(strings.settingsIntro)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Section(strings.sensitivitySectionTitle) {
                Stepper("\(strings.memoryHogThresholdLabel) \(memoryHogPercent)%",
                        value: $memoryHogPercent,
                        in: 10...80,
                        step: 5)
            }

            Section(strings.detailActivitySectionTitle) {
                if journalService.journal.entries.isEmpty {
                    Text(strings.detailJournalEmptyText)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                } else {
                    Button(strings.detailClearActivity) {
                        journalService.clear()
                    }
                }
            }
        }
        .formStyle(.grouped)
    }
}
