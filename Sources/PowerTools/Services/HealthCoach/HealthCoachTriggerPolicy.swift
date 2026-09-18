// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 PowerTools AI contributors

import Foundation

/// What made the caller ask whether the model may run. Only `explainPressed`
/// is an explicit request from the person; the other two are the panel
/// itself checking whether an automatic mode wants to speak up.
enum HealthCoachTrigger: Equatable {
    case explainPressed
    case panelOpened
    case panelAlreadyOpen
}

/// Non-negotiable system conditions the policy defers to, independent of the
/// findings themselves. Built by the caller from readings Health Coach
/// already has (`ProcessInfo.processInfo.isLowPowerModeEnabled`, the same
/// `ThermalPressure` the detector reads); kept separate from
/// `HealthSignalSnapshot` because nothing else in that snapshot needs them.
struct HealthCoachSystemState: Equatable {
    var lowPowerModeEnabled = false
    var thermalThrottling = false
    var memoryPressureCritical = false

    /// The one real reading every caller (the header's Explain button, the
    /// detail view's "Explain again") should build from — so D4's critical-
    /// memory-pressure refusal can never be silently skipped by a caller
    /// that only had a stale or partial view of these three conditions.
    static func current(thermalPressure: ThermalPressure?, memoryPressure: MemoryPressure) -> HealthCoachSystemState {
        HealthCoachSystemState(
            lowPowerModeEnabled: ProcessInfo.processInfo.isLowPowerModeEnabled,
            thermalThrottling: thermalPressure?.isThrottling ?? false,
            memoryPressureCritical: memoryPressure == .critical)
    }
}

/// The Settings-controlled half of section 3.5 (`docs/ai-health-coach/`).
struct HealthCoachTriggerSettings: Equatable {
    enum Mode: String, CaseIterable {
        case off, onDemand, whenSomethingChanges, scheduled
    }

    var mode: Mode = .onDemand
    /// Only consulted in `.whenSomethingChanges`: the least severity a
    /// finding must reach for a changed finding set to be worth explaining.
    var changeSeverityThreshold: HealthFinding.Severity = .notable
    /// Only consulted in `.scheduled`; one of `Defaults.allowedHealthCoachScheduledIntervalMinutes`.
    var scheduledIntervalMinutes: Int = 15
    var maxCallsPerHour = 4
    var maxCallsPerDay = 20

    static func sanitized(defaults: UserDefaults) -> HealthCoachTriggerSettings {
        HealthCoachTriggerSettings(
            mode: Defaults.sanitizedHealthCoachTriggerMode(defaults.string(forKey: DefaultsKey.healthCoachTriggerMode)),
            changeSeverityThreshold: Defaults.sanitizedHealthCoachChangeSeverity(
                defaults.object(forKey: DefaultsKey.healthCoachChangeSeverity) as? Int),
            scheduledIntervalMinutes: Defaults.sanitizedHealthCoachScheduledInterval(
                defaults.integer(forKey: DefaultsKey.healthCoachScheduledIntervalMinutes)),
            maxCallsPerHour: Defaults.sanitizedPercent(defaults.integer(forKey: DefaultsKey.healthCoachMaxCallsPerHour),
                                                       fallback: 4, range: 1...20),
            maxCallsPerDay: Defaults.sanitizedPercent(defaults.integer(forKey: DefaultsKey.healthCoachMaxCallsPerDay),
                                                      fallback: 20, range: 1...100)
        )
    }
}

/// Whether a call should actually reach a model, reuse the last answer, or
/// fall back to the deterministic template — and why, for the usage section
/// in Settings and for tests to name exactly the rule that fired.
enum HealthCoachTriggerDecision: Equatable {
    case callModel
    case useCache
    case useTemplate(Reason)

    enum Reason: Equatable {
        case off
        case notTriggered
        case cooldownActive
        case hourlyCapReached
        case dailyCapReached
        case lowPowerMode
        case thermalThrottling
        case criticalMemoryPressureLocalProvider
        /// Only ever for an explicit Explain press: the automatic modes
        /// already return `.notTriggered` when there is nothing notable.
        case nothingToExplain
    }
}

/// Pure gatekeeper in front of `HealthNarrator` (task 07). Nothing here calls
/// a model or touches Foundation Models/network types — it only decides
/// whether the caller may.
enum HealthCoachTriggerPolicy {
    /// How long a finding kind that was just explained stays "already said"
    /// before an automatic trigger is allowed to explain it again.
    static let findingKindCooldown: TimeInterval = 30 * 60

    static func decide(now: Date,
                       findings: [HealthFinding],
                       trigger: HealthCoachTrigger,
                       ledger: HealthCoachUsageLedger,
                       settings: HealthCoachTriggerSettings,
                       system: HealthCoachSystemState,
                       providerBoundary: AIContextManifest.Boundary) -> HealthCoachTriggerDecision {
        guard settings.mode != .off else { return .useTemplate(.off) }

        // Explain with nothing wrong would spend a capped model call on an
        // answer the header cannot show (it only shows an explanation while
        // there is a finding for it to answer).
        guard trigger != .explainPressed || !findings.isEmpty else { return .useTemplate(.nothingToExplain) }

        // Decision D4: both run inference on this Mac, adding to pressure
        // that is already critical, so this is refused even via Explain's
        // cooldown bypass below. A remote provider runs elsewhere.
        if system.memoryPressureCritical, providerBoundary == .local {
            return .useTemplate(.criticalMemoryPressureLocalProvider)
        }

        // Hard caps apply to every trigger, Explain included.
        if ledger.callCount(sinceLast: 86_400, asOf: now) >= settings.maxCallsPerDay {
            return .useTemplate(.dailyCapReached)
        }
        if ledger.callCount(sinceLast: 3_600, asOf: now) >= settings.maxCallsPerHour {
            return .useTemplate(.hourlyCapReached)
        }

        if trigger != .explainPressed {
            // Roadmap budgets: no automatic call under either condition.
            // Explain still works — the person asked directly.
            if system.lowPowerModeEnabled { return .useTemplate(.lowPowerMode) }
            if system.thermalThrottling { return .useTemplate(.thermalThrottling) }
        }

        if trigger == .explainPressed {
            return .callModel
        }

        let kinds = Set(findings.map(\.kind))
        switch settings.mode {
        case .off:
            return .useTemplate(.off) // unreachable past the guard above
        case .onDemand:
            return .useTemplate(.notTriggered)
        case .whenSomethingChanges:
            guard let mostSevere = findings.map(\.severity).max(), mostSevere >= settings.changeSeverityThreshold else {
                return .useTemplate(.notTriggered)
            }
            return automaticDecision(kinds: kinds, now: now, ledger: ledger)
        case .scheduled:
            guard findings.contains(where: { $0.severity >= .notable }) else {
                return .useTemplate(.notTriggered)
            }
            guard let lastCallAt = ledger.lastCallAt else { return .callModel }
            if kinds == ledger.lastExplainedKinds { return .useCache }
            let interval = TimeInterval(settings.scheduledIntervalMinutes * 60)
            return now.timeIntervalSince(lastCallAt) >= interval ? .callModel : .useTemplate(.cooldownActive)
        }
    }

    /// Shared by `.whenSomethingChanges`: an exactly unchanged finding set
    /// reuses the cached answer; a changed one still waits out the
    /// per-finding-kind cooldown before calling again.
    private static func automaticDecision(kinds: Set<HealthFinding.Kind>,
                                          now: Date,
                                          ledger: HealthCoachUsageLedger) -> HealthCoachTriggerDecision {
        guard let lastCallAt = ledger.lastCallAt else { return .callModel }
        if kinds == ledger.lastExplainedKinds { return .useCache }
        return now.timeIntervalSince(lastCallAt) >= findingKindCooldown ? .callModel : .useTemplate(.cooldownActive)
    }
}
