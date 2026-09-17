// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 PowerTools AI contributors

import Combine
import Foundation

/// The in-memory home for `HealthCoachUsageLedger`, published so the
/// Settings page's live usage numbers update as calls happen. Nothing calls
/// `recordCall` yet — that arrives with `HealthNarrator` in task 07 — so
/// today this only ever shows zero, same as the journal did before task 05
/// wired its event sources.
final class HealthCoachUsageLedgerService: ObservableObject {
    static let shared = HealthCoachUsageLedgerService()

    @Published private(set) var ledger = HealthCoachUsageLedger()

    private init() {}

    func recordCall(at now: Date = Date(), findingKinds: Set<HealthFinding.Kind>, estimatedTokens: Int) {
        ledger.recordCall(at: now, findingKinds: findingKinds, estimatedTokens: estimatedTokens)
    }

    func reset() {
        ledger.reset()
    }
}
