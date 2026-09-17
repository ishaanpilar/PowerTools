// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 PowerTools AI contributors

import Foundation

/// A condition the detector found, carrying the exact evidence that proved
/// it — every sentence the narrator or the template writes must trace back
/// to one of these values, never to a number it invents.
enum HealthFinding: Equatable {
    case batteryLow(chargePercent: Int, thresholdPercent: Int)
    case thermal(level: ThermalPressure, topCPUApp: ProcessUsage?)
    case memoryPressureCritical(usedBytes: UInt64, totalBytes: UInt64?, swapBytes: UInt64?, topApps: [ProcessUsage])
    case diskLow(device: HealthDiskEvidence, thresholdPercent: Int)
    case memoryPressureWarning(usedBytes: UInt64, totalBytes: UInt64?, swapBytes: UInt64?, topApps: [ProcessUsage])
    case memoryHog(app: ProcessUsage, percentOfTotal: Double, thresholdPercent: Int)
    case swapGrowth(beforeBytes: UInt64, afterBytes: UInt64, windowSeconds: TimeInterval)
    case cpuSustained(usage: Double, thresholdPercent: Int, topApps: [ProcessUsage])
    case knownActivity(HealthActivitySighting)
    case updateAvailable

    enum Severity: Int, Comparable {
        case info, notable, critical

        static func < (lhs: Severity, rhs: Severity) -> Bool { lhs.rawValue < rhs.rawValue }
    }

    var severity: Severity {
        switch self {
        case .batteryLow, .diskLow, .memoryPressureCritical:
            return .critical
        case .thermal(let level, _):
            return level == .critical ? .critical : .notable
        case .memoryPressureWarning, .memoryHog, .swapGrowth, .cpuSustained:
            return .notable
        case .knownActivity, .updateAvailable:
            return .info
        }
    }

    /// A finding's identity with its evidence stripped, so the activity
    /// journal can tell "the same condition, still true" apart from "a new
    /// one" without holding onto (and comparing) full evidence, and without
    /// two different apps compiling being counted as one finding.
    enum Kind: Hashable {
        case batteryLow, thermal, memoryPressureCritical, diskLow, memoryPressureWarning
        case memoryHog(appPID: pid_t)
        case swapGrowth
        case cpuSustained
        case knownActivity(appPID: pid_t, activity: HealthActivity)
        case updateAvailable
    }

    var kind: Kind {
        switch self {
        case .batteryLow: return .batteryLow
        case .thermal: return .thermal
        case .memoryPressureCritical: return .memoryPressureCritical
        case .diskLow: return .diskLow
        case .memoryPressureWarning: return .memoryPressureWarning
        case .memoryHog(let app, _, _): return .memoryHog(appPID: app.pid)
        case .swapGrowth: return .swapGrowth
        case .cpuSustained: return .cpuSustained
        case .knownActivity(let sighting): return .knownActivity(appPID: sighting.appPID, activity: sighting.activity)
        case .updateAvailable: return .updateAvailable
        }
    }

    /// Most urgent first. A fixed rank rather than case order, so reordering
    /// the cases above for readability can never silently reorder the header.
    fileprivate var priority: Int {
        switch self {
        case .batteryLow: return 0
        case .thermal: return 1
        case .memoryPressureCritical: return 2
        case .diskLow: return 3
        case .memoryPressureWarning: return 4
        case .memoryHog: return 5
        case .swapGrowth: return 6
        case .cpuSustained: return 7
        case .knownActivity: return 8
        case .updateAvailable: return 9
        }
    }
}

extension Sequence where Element == HealthFinding {
    /// Most urgent first, matching `priority`; ties keep their relative order.
    var orderedByUrgency: [HealthFinding] {
        enumerated()
            .sorted { $0.element.priority != $1.element.priority
                ? $0.element.priority < $1.element.priority
                : $0.offset < $1.offset }
            .map(\.element)
    }
}
