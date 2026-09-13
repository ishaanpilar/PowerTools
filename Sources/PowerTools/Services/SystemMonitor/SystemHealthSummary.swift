// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint
// Copyright (C) 2026 PowerTools contributors

import Foundation

/// A condition worth naming in the panel header's one-line summary, most
/// urgent first. Deliberately narrower than `MonitorAlertService`: it skips
/// CPU usage and CPU/battery temperature, which are the most spike-prone
/// readings and would need `SustainedAlertGate`-style debouncing to avoid a
/// greeting line that flickers mid-sentence; the ones kept here are already
/// slow-changing (thermal pressure and memory pressure are governed kernel
/// states, not raw sensors, and storage/battery/update state moves over
/// minutes, not seconds).
enum SystemHealthCondition: CaseIterable {
    case batteryCriticallyLow
    case thermalCritical
    case memoryPressureCritical
    case diskCriticallyLow
    case updateAvailable

    func message(_ s: Strings) -> String {
        switch self {
        case .batteryCriticallyLow: return s.healthBatteryCriticallyLow
        case .thermalCritical: return s.healthThermalCritical
        case .memoryPressureCritical: return s.healthMemoryCritical
        case .diskCriticallyLow: return s.healthDiskCriticallyLow
        case .updateAvailable: return s.updateBannerTitle
        }
    }
}

enum SystemHealthSummary {
    /// Every condition currently true, most urgent first (case order above).
    /// Reuses the exact threshold values Settings -> Monitor -> Alerts
    /// already exposes (or their defaults) so "notable" means the same
    /// number in both places, but — unlike those alerts — runs regardless of
    /// whether notifications for that metric are turned on: this is passive
    /// "at a glance" text seen only because the panel is already open, not a
    /// proactive interruption, so it owes nothing to the opt-in alert flags.
    static func conditions(for snapshot: SystemSnapshot,
                           updateAvailable: Bool,
                           defaults: UserDefaults = .standard) -> [SystemHealthCondition] {
        var result: [SystemHealthCondition] = []

        if AppFeature.monitorPower.isAvailable, PowerSampler.hasInternalBattery,
           let power = snapshot.power, power.hasBattery, !power.isCharging,
           let charge = power.chargePercent {
            let threshold = Defaults.sanitizedPercent(
                defaults.integer(forKey: DefaultsKey.monitorAlertBatteryPercent),
                fallback: 15, range: 5...50)
            if charge <= threshold { result.append(.batteryCriticallyLow) }
        }

        if AppFeature.monitorCPU.isAvailable, snapshot.thermalPressure == .critical {
            result.append(.thermalCritical)
        }

        if AppFeature.monitorMemory.isAvailable, snapshot.memoryPressure == .critical {
            result.append(.memoryPressureCritical)
        }

        if AppFeature.monitorDisk.isAvailable, let devices = snapshot.disk?.devices {
            let threshold = Defaults.sanitizedPercent(
                defaults.integer(forKey: DefaultsKey.monitorAlertDiskFreePercent),
                fallback: 10, range: 5...30)
            // Same 10 GB sanity floor lowDisk() uses: a nearly-full 4 GB
            // recovery partition is not a condition worth naming.
            let low = devices.contains { device in
                guard device.totalBytes >= 10_000_000_000 else { return false }
                return Double(device.freeBytes) / Double(device.totalBytes) * 100 < Double(threshold)
            }
            if low { result.append(.diskCriticallyLow) }
        }

        if updateAvailable {
            result.append(.updateAvailable)
        }

        return result
    }
}
