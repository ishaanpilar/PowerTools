// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint
// Copyright (C) 2026 PowerTools contributors

import Foundation

/// One refresh tick of the system monitor. Optionals stay nil when a reading
/// is unavailable on the current hardware, and the UI hides those rows.
struct SystemSnapshot {
    var cpuTemperature: Double?
    /// When the CPU sensor behind `cpuTemperature` was last read, on the
    /// system uptime clock. The value is carried between reads, so anything
    /// judging how long the CPU has been hot has to tell repeats apart from
    /// fresh readings.
    var cpuTemperatureReadAt: TimeInterval?
    var gpuTemperature: Double?
    var batteryTemperature: Double?
    /// The uptime timestamp of the last real battery sensor read. Cached values
    /// keep their original timestamp so they cannot age into a sustained alert.
    var batteryTemperatureReadAt: TimeInterval?
    var cpuUsage: Double?          // 0...1
    /// When `cpuUsage` was last really read, on the system uptime clock; the
    /// value is carried over failed reads, and the hot CPU alert has to tell
    /// those repeats apart from fresh readings.
    var cpuUsageReadAt: TimeInterval?
    var gpuUsage: Double?          // 0...1
    var memoryUsed: UInt64?
    var memoryAppUsed: UInt64?
    var memoryTotal: UInt64?
    var memoryCompressed: UInt64?
    var memoryCached: UInt64?
    var memorySwapUsed: UInt64?
    var memoryPressure: MemoryPressure = .unknown
    var fanSpeeds: [Double] = []

    // Thermal
    /// The kernel's 5-level thermal pressure; nil when it cannot be read.
    var thermalPressure: ThermalPressure?
    /// Intel-only CPU speed/scheduler limits; nil on Apple Silicon.
    var throttle: ThrottleInfo?

    // Network
    var netDownBytesPerSec: Double?
    var netUpBytesPerSec: Double?
    var netTotalDown: UInt64?      // since the app started watching
    var netTotalUp: UInt64?

    // Power
    var power: PowerReading?
    var peripheralBatteries: [PeripheralBatteryDevice] = []

    // Disk
    var disk: DiskReading?

    // History (oldest → newest) for the graphs
    var cpuHistory: [Double] = []          // 0...1
    var cpuTemperatureHistory: [Double] = [] // °C, real sensor reads only
    var gpuHistory: [Double] = []          // 0...1
    var memoryHistory: [Double] = []       // 0...1
    var memoryAppHistory: [Double] = []    // 0...1
    var netDownHistory: [Double] = []      // bytes/sec
    var netUpHistory: [Double] = []        // bytes/sec
    var diskReadHistory: [Double] = []     // bytes/sec
    var diskWriteHistory: [Double] = []    // bytes/sec
    var systemPowerHistory: [Double] = []  // watts
    var batteryHistory: [Double] = []      // 0...1 charge level
}
