// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 PowerTools AI contributors

import SwiftUI

/// Skeleton page (`docs/ai-health-coach/`, task 04): the panel header already
/// narrates findings unconditionally once this feature is installed or not —
/// installing it only reveals the one control that already has a real,
/// working effect, `healthCoachMemoryHogPercent`. Narration mode, limits, the
/// provider choice and the activity journal are later tasks; this page grows
/// into them rather than being replaced.
struct HealthCoachSettings: View {
    @ObservedObject private var l10n = L10n.shared
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
        }
        .formStyle(.grouped)
    }
}
