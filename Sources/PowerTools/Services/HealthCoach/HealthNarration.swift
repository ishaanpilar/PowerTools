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
