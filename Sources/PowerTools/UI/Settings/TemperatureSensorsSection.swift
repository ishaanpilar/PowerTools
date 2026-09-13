// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 PowerTools contributors
//
// The sensor browser idea comes from MacTelemetry
// (https://github.com/ishaanpilar/MacTelemetry), MIT © 2025 Ishaan Pilar.

import SwiftUI

/// Lists every temperature sensor the SMC reports, read live only while the
/// list is expanded. Browse-only on purpose: the CPU temperature keeps its
/// curated per-chip sensor selection, and this list just marks which sensors
/// that selection uses, so the menu bar value and the temperature alert keep
/// meaning the same thing.
struct TemperatureSensorsSection: View {
    @ObservedObject private var l10n = L10n.shared
    @AppStorage(DefaultsKey.temperatureUnit) private var temperatureUnit = TemperatureUnit.celsius.rawValue
    @State private var expanded = false

    var body: some View {
        Section(l10n.s.monitorSensorsSection) {
            Text(l10n.s.monitorSensorsCaption)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            // The page's own disclosure idiom, as in "In the panel" beside it:
            // the whole row toggles and the chevron sits trailing. The list
            // exists only while expanded, which is what scopes its polling.
            DisclosureHeaderRow(isExpanded: $expanded) {
                Text(l10n.s.monitorSensorsShow)
                Spacer()
            }
            if expanded {
                SensorList(unit: TemperatureUnit(rawValue: temperatureUnit) ?? .celsius)
                    .disclosureIndent()
            }
        }
    }
}

/// The expanded list. It owns the polling, and it only exists while the
/// disclosure is open, so polling starts on expand and is cancelled on
/// collapse or when the page goes away. Kept as one container so `.task`
/// attaches once rather than once per row.
private struct SensorList: View {
    @ObservedObject private var l10n = L10n.shared
    let unit: TemperatureUnit
    @State private var sensors: [TemperatureSensorReading] = []
    @State private var loaded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            if !loaded {
                ProgressView()
                    .controlSize(.small)
                    .frame(maxWidth: .infinity)
            } else if sensors.isEmpty {
                Text(l10n.s.monitorSensorsEmpty)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(sensors) { sensor in
                    row(sensor)
                }
                Text(String(format: l10n.s.monitorSensorsCountFormat, sensors.count))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.top, 2)
            }
        }
        .task {
            while !Task.isCancelled {
                sensors = await SystemMonitor.shared.temperatureSensorReadings()
                loaded = true
                try? await Task.sleep(for: .seconds(2))
            }
        }
    }

    private func row(_ sensor: TemperatureSensorReading) -> some View {
        HStack(spacing: 6) {
            Text(sensor.name)
                .font(.system(.body, design: .monospaced))
            if sensor.isCPU {
                Text(l10n.s.monitorSensorsCPUBadge)
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 1)
                    .overlay(Capsule().strokeBorder(.secondary.opacity(0.5), lineWidth: 0.7))
            }
            Spacer(minLength: 8)
            Text(MetricFormat.temperature(sensor.value, unit: unit))
                .monospacedDigit()
        }
    }
}
