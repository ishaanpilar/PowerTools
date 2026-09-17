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
    @ObservedObject private var usageLedgerService = HealthCoachUsageLedgerService.shared
    @AppStorage(DefaultsKey.healthCoachMemoryHogPercent) private var memoryHogPercent = 30
    @AppStorage(DefaultsKey.healthCoachTriggerMode) private var triggerModeRaw = HealthCoachTriggerSettings.Mode.onDemand.rawValue
    @AppStorage(DefaultsKey.healthCoachChangeSeverity) private var changeSeverityRaw = HealthFinding.Severity.notable.rawValue
    @AppStorage(DefaultsKey.healthCoachScheduledIntervalMinutes) private var scheduledIntervalMinutes = 15
    @AppStorage(DefaultsKey.healthCoachMaxCallsPerHour) private var maxCallsPerHour = 4
    @AppStorage(DefaultsKey.healthCoachMaxCallsPerDay) private var maxCallsPerDay = 20

    private var strings: HealthCoachStrings { FeatureStrings.healthCoach(l10n.language) }

    private var triggerMode: HealthCoachTriggerSettings.Mode {
        Defaults.sanitizedHealthCoachTriggerMode(triggerModeRaw)
    }

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

            Section(strings.narrationSectionTitle) {
                Picker(strings.narrationModeLabel, selection: $triggerModeRaw) {
                    ForEach(HealthCoachTriggerSettings.Mode.allCases, id: \.rawValue) { mode in
                        Text(strings.label(for: mode)).tag(mode.rawValue)
                    }
                }

                if triggerMode == .whenSomethingChanges {
                    Picker(strings.narrationChangeSeverityLabel, selection: $changeSeverityRaw) {
                        ForEach([HealthFinding.Severity.notable, .critical], id: \.rawValue) { severity in
                            if let label = strings.label(for: severity) {
                                Text(label).tag(severity.rawValue)
                            }
                        }
                    }
                }

                if triggerMode == .scheduled {
                    Picker(strings.narrationScheduledIntervalLabel, selection: $scheduledIntervalMinutes) {
                        ForEach(Defaults.allowedHealthCoachScheduledIntervalMinutes, id: \.self) { minutes in
                            Text(String(format: strings.scheduledIntervalFormat, minutes)).tag(minutes)
                        }
                    }
                }
            }

            Section(strings.limitsSectionTitle) {
                Stepper("\(strings.limitsPerHourLabel): \(maxCallsPerHour)", value: $maxCallsPerHour, in: 1...20)
                Stepper("\(strings.limitsPerDayLabel): \(maxCallsPerDay)", value: $maxCallsPerDay, in: 1...100)
                Text(String(format: strings.limitsUsageFormat,
                           usageLedgerService.ledger.callCount(sinceLast: 86_400, asOf: Date()),
                           usageLedgerService.ledger.callCount(sinceLast: 3_600, asOf: Date())))
                    .font(.callout)
                    .foregroundStyle(.secondary)
                if !usageLedgerService.ledger.calls.isEmpty {
                    Button(strings.limitsResetButton) {
                        usageLedgerService.reset()
                    }
                }
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
