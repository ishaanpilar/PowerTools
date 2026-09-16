// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 PowerTools AI contributors

import Foundation

/// Turns one `HealthFinding` into a sentence without any model, from the
/// exact evidence the finding carries — never a number or a name the finding
/// did not supply. This is what the header always has to show: whenever AI
/// narration (a later task) is off, unavailable, declined, deferred,
/// rate-limited or wrong, the header falls back to this, so it is never
/// blank and never waits on a model.
enum HealthNarrationTemplate {
    static func headline(for finding: HealthFinding, strings: Strings, healthCoach: HealthCoachStrings) -> String {
        switch finding {
        case .batteryLow:
            return strings.healthBatteryCriticallyLow
        case .thermal(let level, _):
            return level == .critical ? strings.healthThermalCritical : healthCoach.thermalThrottling
        case .memoryPressureCritical:
            return strings.healthMemoryCritical
        case .memoryPressureWarning:
            return healthCoach.memoryPressureWarning
        case .diskLow:
            return strings.healthDiskCriticallyLow
        case .memoryHog(let app, let percentOfTotal, _):
            return String(format: healthCoach.memoryHogFormat, app.name, Int(percentOfTotal.rounded()))
        case .swapGrowth(_, let afterBytes, _):
            // beforeBytes is also on the finding for evidence, but the
            // sentence only needs the level someone would actually notice.
            return String(format: healthCoach.swapGrowthFormat, MetricFormat.bytes(afterBytes),
                          MetricFormat.bytes(finding.swapGrowthBeforeBytes ?? 0))
        case .cpuSustained(let usage, _, let topApps):
            guard let app = topApps.first else {
                return String(format: healthCoach.cpuSustainedFormat, "", Int((usage * 100).rounded()))
            }
            return String(format: healthCoach.cpuSustainedFormat, app.name, Int((usage * 100).rounded()))
        case .knownActivity(let sighting):
            let phrase = healthCoach.phrase(for: sighting.activity)
            if sighting.valueIsMemoryBytes {
                return String(format: healthCoach.activityWithMemoryFormat, sighting.appName, phrase,
                              MetricFormat.bytes(UInt64(max(0, sighting.appValue))))
            }
            return String(format: healthCoach.activityWithCPUFormat, sighting.appName, phrase,
                          Int(sighting.appValue.rounded()))
        case .updateAvailable:
            return strings.updateBannerTitle
        }
    }
}

private extension HealthFinding {
    /// Only `swapGrowth` carries this; used above purely to keep the
    /// `headline` switch from repeating the pattern match.
    var swapGrowthBeforeBytes: UInt64? {
        if case .swapGrowth(let before, _, _) = self { return before }
        return nil
    }
}
