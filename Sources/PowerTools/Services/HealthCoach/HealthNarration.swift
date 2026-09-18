// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 PowerTools AI contributors

import Foundation

/// One validated answer from `HealthNarrator`: a headline the header can
/// show in place of the template, plus up to three detail bullets for the
/// expanded view. Everything here has already passed
/// `HealthNarratorValidator` — nothing downstream needs to re-check it.
struct HealthNarration: Equatable {
    let headline: String
    let bullets: [String]
    /// The finding kinds this explains, so a later read can tell "still the
    /// same situation" (serve from `current`/the cache) from "something
    /// changed" (stale, needs a fresh call) without re-running the model.
    let findingKinds: Set<HealthFinding.Kind>
    let providerID: String
    let providerBoundary: AIContextManifest.Boundary
    let generatedAt: Date
}

/// Why an explicit Explain press produced no explanation, so the detail view
/// can say so instead of looking like the button did nothing. Never raised
/// for an automatic trigger: those stay quiet by design, nobody asked.
enum HealthNarratorNotice: Equatable {
    case nothingToExplain
    case off
    case hourlyCap
    case dailyCap
    case memoryCritical
    case providerUnavailable
    case replyRejected
    case failed

    /// The reasons that mean "not now" to a person who pressed Explain.
    /// `nil` for the ones an explicit press can never hit (an automatic
    /// mode's own gating), so a stray one is never worded as an error.
    init?(_ reason: HealthCoachTriggerDecision.Reason) {
        switch reason {
        case .nothingToExplain: self = .nothingToExplain
        case .off: self = .off
        case .hourlyCapReached: self = .hourlyCap
        case .dailyCapReached: self = .dailyCap
        case .criticalMemoryPressureLocalProvider: self = .memoryCritical
        case .notTriggered, .cooldownActive, .lowPowerMode, .thermalThrottling: return nil
        }
    }
}
