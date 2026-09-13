// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 PowerTools contributors
//
// Ported from MacTelemetry (https://github.com/ishaanpilar/MacTelemetry),
// MIT © 2025 Ishaan Pilar, and relicensed here under GPL-3.0-or-later as
// permitted by the MIT license.

import Darwin
import Foundation

/// How far the system is currently holding the CPU back.
struct ThrottleInfo: Equatable {
    /// Percentage of full clock speed the CPU is allowed, 100 when unthrottled.
    var speedLimit: Int?
    /// Percentage of scheduler capacity available.
    var schedulerLimit: Int?
    /// CPUs currently offered to the scheduler.
    var availableCPUs: Int?

    var isThrottled: Bool {
        if let speedLimit { return speedLimit < 100 }
        return false
    }
}

/// Reads the CPU throttle figures macOS exposes through `pmset -g therm`.
///
/// This is the only genuine throttle measurement available without root, and
/// **only Intel Macs report it** — Apple Silicon has no equivalent field, so
/// the reader answers `isSupported == false` there and never spawns anything.
///
/// It costs a subprocess per read, which is why `MonitorSamplingKind.cpuThrottle`
/// carries a long stride. Reads go through `Shell.run`, so a `pmset` that stops
/// answering is bounded rather than holding a sampling thread for good.
enum ThrottleReader {
    /// True on Intel. Apple Silicon sets `hw.optional.arm64` to 1; on Intel the
    /// sysctl is absent, which is what distinguishes them.
    static let isSupported: Bool = {
        var value: Int32 = 0
        var size = MemoryLayout<Int32>.size
        let result = sysctlbyname("hw.optional.arm64", &value, &size, nil, 0)
        return !(result == 0 && value == 1)
    }()

    static func read() -> ThrottleInfo? {
        guard isSupported else { return nil }
        let result = Shell.run("/usr/bin/pmset", ["-g", "therm"], timeout: 3)
        guard result.status == 0 else { return nil }
        return parse(result.output)
    }

    /// Split out so the parser is testable without running `pmset`.
    ///
    /// The real output pads the `=` with spaces and, on a Mac that has never
    /// throttled, carries a "No thermal warning level has been recorded" note
    /// and no fields at all — which reads as nil, not as zero.
    static func parse(_ output: String) -> ThrottleInfo? {
        var info = ThrottleInfo()
        for line in output.split(separator: "\n") {
            let compact = line.filter { !$0.isWhitespace }
            let parts = compact.split(separator: "=")
            guard parts.count == 2, let value = Int(parts[1]) else { continue }
            switch parts[0] {
            case "CPU_Speed_Limit": info.speedLimit = value
            case "CPU_Scheduler_Limit": info.schedulerLimit = value
            case "CPU_Available_CPUs": info.availableCPUs = value
            default: break
            }
        }
        guard info != ThrottleInfo() else { return nil }
        return info
    }
}
