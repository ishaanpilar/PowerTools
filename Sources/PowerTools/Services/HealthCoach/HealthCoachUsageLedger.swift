// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 PowerTools AI contributors

import Foundation

/// A record of every model call Health Coach has made, kept in memory only
/// (never written to disk, matching the journal). Rolling windows rather
/// than calendar-day boundaries, so "today" and "this hour" need no
/// timezone or midnight-rollover handling and stay exactly as testable with
/// an injected `now` as everything else in this feature.
struct HealthCoachUsageLedger: Equatable {
    struct Call: Equatable {
        let at: Date
        let estimatedTokens: Int
    }

    private(set) var calls: [Call] = []
    /// The finding kinds explained by the most recent call, so the trigger
    /// policy can tell "still the same situation" from "something new."
    private(set) var lastExplainedKinds: Set<HealthFinding.Kind> = []

    var lastCallAt: Date? { calls.last?.at }

    mutating func recordCall(at now: Date, findingKinds: Set<HealthFinding.Kind>, estimatedTokens: Int) {
        calls.append(Call(at: now, estimatedTokens: estimatedTokens))
        lastExplainedKinds = findingKinds
    }

    func callCount(sinceLast window: TimeInterval, asOf now: Date) -> Int {
        calls.filter { now.timeIntervalSince($0.at) < window }.count
    }

    func estimatedTokens(sinceLast window: TimeInterval, asOf now: Date) -> Int {
        calls.filter { now.timeIntervalSince($0.at) < window }.reduce(0) { $0 + $1.estimatedTokens }
    }

    mutating func reset() {
        calls = []
        lastExplainedKinds = []
    }
}
