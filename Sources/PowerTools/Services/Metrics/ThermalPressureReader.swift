// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 PowerTools contributors
//
// Ported from MacTelemetry (https://github.com/ishaanpilar/MacTelemetry),
// MIT © 2025 Ishaan Pilar, and relicensed here under GPL-3.0-or-later as
// permitted by the MIT license.

import Foundation
import notify

/// The system's thermal pressure level.
///
/// Five levels, where `ProcessInfo.thermalState` only exposes four: the kernel
/// separates two degrees of serious pressure that `ProcessInfo` folds together.
/// Ordered, so the alert gate can compare severities.
enum ThermalPressure: Int, Comparable, Equatable {
    case nominal = 0
    case moderate = 1
    case heavy = 2
    case critical = 3

    static func < (lhs: ThermalPressure, rhs: ThermalPressure) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    /// Whether the system is shedding performance to control heat. Below this
    /// the Mac is warm but running at full speed.
    var isThrottling: Bool { self >= .heavy }
}

/// Reads thermal pressure from the Darwin notification the kernel publishes —
/// the same source `powermetrics -s thermal` reads, but without root, a helper
/// or a subprocess.
///
/// `notify_register_check` sets up a shared-memory slot the kernel writes into,
/// so each read is a memory load rather than a round trip. Cheap enough to
/// sample on every monitor tick.
///
/// Not thread-safe by itself: `SystemMonitor` owns one and only touches it from
/// its sampling queue, the same way it owns its other samplers.
final class ThermalPressureReader {
    private var token: Int32 = NOTIFY_TOKEN_INVALID
    private var registered = false

    init() {
        registered = notify_register_check(Self.notificationName, &token) == NOTIFY_STATUS_OK
    }

    deinit {
        if registered { notify_cancel(token) }
    }

    private static let notificationName = "com.apple.system.thermalpressurelevel"

    /// The current level, or nil when the notification is unavailable — which
    /// is how callers distinguish "not throttling" from "cannot tell".
    func read() -> ThermalPressure? {
        guard registered else { return nil }
        var state: UInt64 = 0
        guard notify_get_state(token, &state) == NOTIFY_STATUS_OK else { return nil }
        // The kernel publishes more values than it documents; anything at or
        // beyond the top defined level is treated as critical rather than
        // discarded, so a future level cannot read as "fine".
        switch state {
        case 0: return .nominal
        case 1: return .moderate
        case 2: return .heavy
        default: return .critical
        }
    }
}
