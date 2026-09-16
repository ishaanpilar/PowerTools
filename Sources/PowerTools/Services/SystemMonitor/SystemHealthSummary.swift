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

/// A thin adapter over `HealthFindingDetector` (`docs/ai-health-coach/`): the
/// header's own immediate, ungated glance text stays exactly as before —
/// thermal and memory pressure are kernel-state comparisons with no
/// threshold, so there is nothing for a second copy to drift on — but every
/// actual *number* here, the battery and disk percentages and the 10 GB disk
/// floor, now comes from `HealthFindingThresholds` and
/// `HealthFindingDetector.lowestDisk`, the same values Health Coach's fuller,
/// gated findings use. Threading the detector's `SustainedAlertGate`s into
/// this stateless, every-render header call is deliberately left to the task
/// that changes what the header shows.
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
        let thresholds = HealthFindingThresholds.sanitized(defaults: defaults)

        if AppFeature.monitorPower.isAvailable, PowerSampler.hasInternalBattery,
           let power = snapshot.power, power.hasBattery, !power.isCharging,
           let charge = power.chargePercent, charge <= thresholds.batteryPercent {
            result.append(.batteryCriticallyLow)
        }

        if AppFeature.monitorCPU.isAvailable, snapshot.thermalPressure == .critical {
            result.append(.thermalCritical)
        }

        if AppFeature.monitorMemory.isAvailable, snapshot.memoryPressure == .critical {
            result.append(.memoryPressureCritical)
        }

        if AppFeature.monitorDisk.isAvailable, let devices = snapshot.disk?.devices {
            let evidence = devices.map {
                HealthDiskEvidence(name: $0.name, freeBytes: $0.freeBytes, totalBytes: $0.totalBytes)
            }
            if HealthFindingDetector.lowestDisk(among: evidence,
                                               floor: HealthFindingThresholds.diskDeviceFloorBytes,
                                               belowPercent: thresholds.diskFreePercent) != nil {
                result.append(.diskCriticallyLow)
            }
        }

        if updateAvailable {
            result.append(.updateAvailable)
        }

        return result
    }
}
