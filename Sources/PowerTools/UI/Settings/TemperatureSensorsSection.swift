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
    @State private var sensors: [TemperatureSensorReading] = []
    @State private var loaded = false

    private var unit: TemperatureUnit {
        TemperatureUnit(rawValue: temperatureUnit) ?? .celsius
    }

    var body: some View {
        Section(l10n.s.monitorSensorsSection) {
            Text(l10n.s.monitorSensorsCaption)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            DisclosureGroup(l10n.s.monitorSensorsShow, isExpanded: $expanded) {
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
                }
            }
        }
        // Polls only while expanded; the task is cancelled when the list
        // collapses or the page goes away, so a closed list costs nothing.
        .task(id: expanded) {
            guard expanded else { return }
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
