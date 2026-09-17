// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 PowerTools AI contributors

import Foundation

/// Where an evidence chip in the detail popover jumps to. Lives in UI, not
/// in the Services-layer `HealthFinding`, since `MetricDetailKind` is a
/// panel view concept the detector has no business knowing about.
extension HealthFinding {
    var metricDetailKind: MetricDetailKind? {
        switch self {
        case .batteryLow: return .battery
        case .thermal, .cpuSustained: return .cpu
        case .memoryPressureCritical, .memoryPressureWarning, .memoryHog, .swapGrowth: return .memory
        case .diskLow: return .disk
        case .knownActivity(let sighting): return sighting.valueIsMemoryBytes ? .memory : .cpu
        case .updateAvailable: return nil
        }
    }
}
