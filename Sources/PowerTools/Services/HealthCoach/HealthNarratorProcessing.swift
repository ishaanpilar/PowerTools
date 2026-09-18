// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 PowerTools AI contributors

import Foundation

/// What a finished raw model reply means, decoupled from the async
/// streaming machinery around it (`HealthNarratorService`) and from the
/// singletons that machinery depends on — this is the part carrying the
/// real safety weight (never trust an unvalidated answer), kept in its own
/// dependency-free file so it can be exercised directly by a test without
/// pulling in `L10n`, `HealthCoachUsageLedgerService` or a live provider.
enum HealthNarratorProcessing {
    static func process(raw: String, findings: [HealthFinding], kinds: Set<HealthFinding.Kind>,
                        providerID: String, providerBoundary: AIContextManifest.Boundary,
                        now: Date = Date()) -> HealthNarration? {
        guard let parsed = HealthNarratorValidator.validate(raw, findings: findings) else { return nil }
        return HealthNarration(headline: parsed.headline, bullets: parsed.bullets, findingKinds: kinds,
                               providerID: providerID, providerBoundary: providerBoundary, generatedAt: now)
    }
}
