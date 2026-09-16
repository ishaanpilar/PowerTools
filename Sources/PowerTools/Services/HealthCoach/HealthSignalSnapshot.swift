// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 PowerTools AI contributors

import Foundation

/// The disk-low rule's own minimal view of one volume, kept as plain fields
/// rather than the whole `DiskDeviceReading` so this stays a value only
/// Health Coach owns.
struct HealthDiskEvidence: Equatable {
    let name: String
    let freeBytes: UInt64
    let totalBytes: UInt64
}

/// A recognised activity running inside one app's row.
struct HealthActivitySighting: Equatable {
    let appPID: pid_t
    let appName: String
    let activity: HealthActivity
    /// Running processes of that activity folded into the app.
    let processCount: Int
    /// The app row's value: bytes for memory rows, percent for CPU rows.
    let appValue: Double
    /// Whether `appValue` is memory (bytes) rather than CPU (percent), so a
    /// caller can format it without guessing from the magnitude.
    let valueIsMemoryBytes: Bool
}

/// Everything Health Coach may reason about at one moment, built only from
/// readings the monitor already holds. A plain value, so detection and
/// narration can be tested without a live Mac.
struct HealthSignalSnapshot: Equatable {
    var memoryPressure: MemoryPressure = .unknown
    var memoryUsedBytes: UInt64?
    var memoryTotalBytes: UInt64?
    var swapUsedBytes: UInt64?
    /// 0...1
    var cpuUsage: Double?
    /// System uptime of the last real CPU read, so repeats are not mistaken
    /// for a sustained reading.
    var cpuUsageReadAt: TimeInterval?
    var thermalPressure: ThermalPressure?
    /// Heaviest apps by memory footprint (bytes), helpers consolidated.
    var topMemory: [ProcessUsage] = []
    /// Heaviest apps by CPU (percent), helpers consolidated.
    var topCPU: [ProcessUsage] = []
    var keepAwakeActive = false
    var recordingActive = false
    var updateAvailable = false
    var hasInternalBattery = false
    var batteryIsCharging = false
    var batteryChargePercent: Int?
    var diskDevices: [HealthDiskEvidence] = []
    /// System uptime when this snapshot was assembled, so the swap-growth
    /// rule can tell how much time actually passed since `previous`.
    var capturedAt: TimeInterval?

    /// Recognised activities across the top rows, one per app and activity,
    /// memory rows first since they carry the size worth quoting.
    var activitySightings: [HealthActivitySighting] {
        var seen = Set<String>()
        var result: [HealthActivitySighting] = []
        for (row, isMemoryRow) in topMemory.map({ ($0, true) }) + topCPU.map({ ($0, false) }) {
            var counts: [HealthActivity: Int] = [:]
            var order: [HealthActivity] = []
            for member in row.members {
                guard let activity = HealthKnownActivity.activity(forProcessName: member.name) else { continue }
                if counts[activity] == nil { order.append(activity) }
                counts[activity, default: 0] += member.count
            }
            for activity in order {
                let key = "\(row.pid)|\(activity.rawValue)"
                guard seen.insert(key).inserted else { continue }
                result.append(HealthActivitySighting(appPID: row.pid,
                                                     appName: row.name,
                                                     activity: activity,
                                                     processCount: counts[activity] ?? 0,
                                                     appValue: row.value,
                                                     valueIsMemoryBytes: isMemoryRow))
            }
        }
        return result
    }
}
