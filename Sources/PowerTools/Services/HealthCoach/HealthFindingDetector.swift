// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 PowerTools AI contributors

import Foundation

/// The `SustainedAlertGate`s a caller must keep across calls, one per rule
/// that needs a reading to hold rather than fire on a single sample.
/// Kernel-governed levels (thermal, disk, battery) do not spike the way a raw
/// sensor does, so — matching `MonitorAlertService`'s own reasoning — they are
/// not gated here.
struct HealthFindingGates {
    var memoryPressure = SustainedAlertGate()
    var cpu = SustainedAlertGate()

    mutating func reset() {
        memoryPressure.reset()
        cpu.reset()
    }
}

/// Detection thresholds, read once per call from the same defaults keys
/// `MonitorAlertService` uses — "notable" means the same number in both
/// places — plus one new setting of Health Coach's own.
struct HealthFindingThresholds: Equatable {
    var cpuPercent = 90
    var memoryHogPercent = 30
    var diskFreePercent = 10
    var batteryPercent = 15

    /// Fixed, not a setting: matches the plan's "swap grew over 2 GB in
    /// 10 min" exactly, so the rule has one meaning everywhere it is tested.
    static let swapGrowthBytes: UInt64 = 2_000_000_000
    static let swapGrowthWindowSeconds: TimeInterval = 600
    /// A 10-GB floor, matching the disk-low rule everywhere else in the app:
    /// a nearly-full recovery partition is not a finding worth naming.
    static let diskDeviceFloorBytes: UInt64 = 10_000_000_000

    static func sanitized(defaults: UserDefaults) -> HealthFindingThresholds {
        HealthFindingThresholds(
            cpuPercent: Defaults.sanitizedPercent(defaults.integer(forKey: DefaultsKey.monitorAlertCPUThreshold),
                                                  fallback: 90, range: 50...100),
            memoryHogPercent: Defaults.sanitizedPercent(defaults.integer(forKey: DefaultsKey.healthCoachMemoryHogPercent),
                                                        fallback: 30, range: 10...80),
            diskFreePercent: Defaults.sanitizedPercent(defaults.integer(forKey: DefaultsKey.monitorAlertDiskFreePercent),
                                                       fallback: 10, range: 5...30),
            batteryPercent: Defaults.sanitizedPercent(defaults.integer(forKey: DefaultsKey.monitorAlertBatteryPercent),
                                                      fallback: 15, range: 5...50)
        )
    }
}

enum HealthFindingDetector {
    /// Every condition currently true, most urgent first. Pure: the only
    /// mutable state is `gates`, which the caller owns and threads through
    /// every call so a reading can be told apart from a repeat of the same
    /// one, exactly like `MonitorAlertService`.
    ///
    /// `previous`, when given, must be a snapshot the caller deliberately
    /// kept from roughly `HealthFindingThresholds.swapGrowthWindowSeconds`
    /// ago, not simply the snapshot from the last call: `swapGrowth` only
    /// evaluates once `snapshot.capturedAt - previous.capturedAt` has
    /// actually reached that window, and otherwise reports nothing for that
    /// rule rather than comparing across too short a gap.
    static func findings(for snapshot: HealthSignalSnapshot,
                         previous: HealthSignalSnapshot?,
                         gates: inout HealthFindingGates,
                         thresholds: HealthFindingThresholds) -> [HealthFinding] {
        var result: [HealthFinding] = []

        if snapshot.hasInternalBattery, !snapshot.batteryIsCharging,
           let charge = snapshot.batteryChargePercent, charge <= thresholds.batteryPercent {
            result.append(.batteryLow(chargePercent: charge, thresholdPercent: thresholds.batteryPercent))
        }

        if let level = snapshot.thermalPressure, level.isThrottling {
            result.append(.thermal(level: level, topCPUApp: snapshot.topCPU.first))
        }

        let memoryLevel: Double = snapshot.memoryPressure == .critical ? 2
            : snapshot.memoryPressure == .warning ? 1 : 0
        if gates.memoryPressure.shouldAlert(reading: memoryLevel, threshold: 1, readAt: snapshot.capturedAt) {
            if snapshot.memoryPressure == .critical {
                result.append(.memoryPressureCritical(usedBytes: snapshot.memoryUsedBytes ?? 0,
                                                       totalBytes: snapshot.memoryTotalBytes,
                                                       swapBytes: snapshot.swapUsedBytes,
                                                       topApps: Array(snapshot.topMemory.prefix(3))))
            } else {
                result.append(.memoryPressureWarning(usedBytes: snapshot.memoryUsedBytes ?? 0,
                                                      totalBytes: snapshot.memoryTotalBytes,
                                                      swapBytes: snapshot.swapUsedBytes,
                                                      topApps: Array(snapshot.topMemory.prefix(3))))
            }
        }

        if let device = lowestDisk(among: snapshot.diskDevices, floor: HealthFindingThresholds.diskDeviceFloorBytes,
                                   belowPercent: thresholds.diskFreePercent) {
            result.append(.diskLow(device: device, thresholdPercent: thresholds.diskFreePercent))
        }

        if let totalBytes = snapshot.memoryTotalBytes, totalBytes > 0, let heaviest = snapshot.topMemory.first {
            let percent = Double(heaviest.value) / Double(totalBytes) * 100
            if percent >= Double(thresholds.memoryHogPercent) {
                result.append(.memoryHog(app: heaviest, percentOfTotal: percent,
                                         thresholdPercent: thresholds.memoryHogPercent))
            }
        }

        if let previous, let before = previous.swapUsedBytes, let after = snapshot.swapUsedBytes,
           let previousCapturedAt = previous.capturedAt, let capturedAt = snapshot.capturedAt,
           capturedAt - previousCapturedAt >= HealthFindingThresholds.swapGrowthWindowSeconds,
           after > before, after - before >= HealthFindingThresholds.swapGrowthBytes {
            result.append(.swapGrowth(beforeBytes: before, afterBytes: after,
                                      windowSeconds: capturedAt - previousCapturedAt))
        }

        if gates.cpu.shouldAlert(reading: snapshot.cpuUsage,
                                 threshold: Double(thresholds.cpuPercent) / 100,
                                 readAt: snapshot.cpuUsageReadAt) {
            result.append(.cpuSustained(usage: snapshot.cpuUsage ?? 0,
                                        thresholdPercent: thresholds.cpuPercent,
                                        topApps: Array(snapshot.topCPU.prefix(3))))
        }

        result.append(contentsOf: snapshot.activitySightings.map(HealthFinding.knownActivity))

        if snapshot.updateAvailable {
            result.append(.updateAvailable)
        }

        return result.orderedByUrgency
    }

    /// The device closest to its threshold, so the finding names one real
    /// volume instead of just "some disk is low." Also used by
    /// `SystemHealthSummary`, so the header's boolean check and this
    /// finding's evidence can never disagree about which device counts.
    static func lowestDisk(among devices: [HealthDiskEvidence],
                           floor: UInt64,
                           belowPercent: Int) -> HealthDiskEvidence? {
        devices
            .filter { $0.totalBytes >= floor }
            .filter { Double($0.freeBytes) / Double($0.totalBytes) * 100 < Double(belowPercent) }
            .min { Double($0.freeBytes) / Double($0.totalBytes) < Double($1.freeBytes) / Double($1.totalBytes) }
    }
}
