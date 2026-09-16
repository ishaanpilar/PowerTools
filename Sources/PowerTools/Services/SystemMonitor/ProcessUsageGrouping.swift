// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint
// Copyright (C) 2026 PowerTools contributors

import Foundation

/// One executable folded into an app's row: its name as `ps` reports it, and
/// how many running processes share that name under the same app.
struct ProcessMember: Equatable {
    let name: String
    let count: Int
}

/// One row of the per-app breakdown shown when a System stat is expanded.
struct ProcessUsage: Identifiable, Equatable {
    let pid: pid_t
    let name: String
    /// CPU/GPU/energy: percentage (0–100). Memory: bytes. Network: total bytes/s.
    let value: Double
    let networkDownBytesPerSec: Double?
    let networkUpBytesPerSec: Double?
    /// The executables consolidated into this row, heaviest first. Empty for
    /// rows that were not grouped.
    let members: [ProcessMember]

    var id: pid_t { pid }

    init(pid: pid_t,
         name: String,
         value: Double,
         networkDownBytesPerSec: Double? = nil,
         networkUpBytesPerSec: Double? = nil,
         members: [ProcessMember] = []) {
        self.pid = pid
        self.name = name
        self.value = value
        self.networkDownBytesPerSec = networkDownBytesPerSec
        self.networkUpBytesPerSec = networkUpBytesPerSec
        self.members = members
    }
}

enum ProcessUsageGrouping {
    /// Sums per-process values under each process's responsible app, heaviest
    /// app first. The row's pid becomes the responsible pid, so the app's
    /// proper name and icon are shown; the helpers' own executable names are
    /// kept in `members`, since the app name alone cannot say that a build or
    /// an indexer is what is running inside it.
    static func grouped(_ rows: [ProcessUsage],
                        owner: (pid_t) -> pid_t,
                        displayName: (pid_t, String) -> String) -> [ProcessUsage] {
        var totals: [pid_t: Double] = [:]
        var fallbackNames: [pid_t: String] = [:]
        var memberValues: [pid_t: [String: (value: Double, count: Int)]] = [:]

        for row in rows {
            let ownerPID = owner(row.pid)
            totals[ownerPID, default: 0] += row.value
            if fallbackNames[ownerPID] == nil {
                fallbackNames[ownerPID] = row.name
            }
            var entry = memberValues[ownerPID, default: [:]][row.name] ?? (0, 0)
            entry.value += row.value
            entry.count += 1
            memberValues[ownerPID, default: [:]][row.name] = entry
        }

        return totals
            .sorted { $0.value != $1.value ? $0.value > $1.value : $0.key < $1.key }
            .map { ownerPID, value in
                let members = (memberValues[ownerPID] ?? [:])
                    .sorted { $0.value.value != $1.value.value ? $0.value.value > $1.value.value : $0.key < $1.key }
                    .map { ProcessMember(name: $0.key, count: $0.value.count) }
                return ProcessUsage(pid: ownerPID,
                                    name: displayName(ownerPID, fallbackNames[ownerPID] ?? "pid \(ownerPID)"),
                                    value: value,
                                    members: members)
            }
    }
}
