// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 PowerTools AI contributors

import Foundation

enum HealthCoachTests {
    static func run(_ suite: TestSuite) {
        groupingChecks(suite)
        knownActivityChecks(suite)
        sightingChecks(suite)
        processSourceChecks(suite)
    }

    private static func groupingChecks(_ suite: TestSuite) {
        let raw = [
            ProcessUsage(pid: 10, name: "swift-frontend", value: 100),
            ProcessUsage(pid: 11, name: "swift-frontend", value: 50),
            ProcessUsage(pid: 12, name: "clang", value: 200),
            ProcessUsage(pid: 20, name: "Safari", value: 30),
            ProcessUsage(pid: 21, name: "com.apple.WebKit.WebContent", value: 400),
        ]
        let owners: [pid_t: pid_t] = [10: 1, 11: 1, 12: 1, 20: 2, 21: 2]
        let grouped = ProcessUsageGrouping.grouped(raw,
                                                   owner: { owners[$0] ?? $0 },
                                                   displayName: { pid, _ in "App \(pid)" })

        func total(of owner: pid_t) -> Double {
            raw.filter { owners[$0.pid] == owner }.reduce(0) { $0 + $1.value }
        }
        suite.expect(grouped.map(\.pid) == [1, 2].sorted { total(of: $0) > total(of: $1) },
                     "grouped process rows are ordered heaviest app first")
        suite.expect(grouped.first { $0.pid == 1 }?.value == total(of: 1),
                     "a grouped process row sums every helper under its responsible app")
        suite.expect(grouped.first { $0.pid == 1 }?.name == "App 1",
                     "a grouped process row takes the responsible app's display name")

        let codeRow = grouped.first(where: { $0.pid == 1 })
        let codeMembers: [ProcessMember] = codeRow?.members ?? []
        let swiftRows = raw.filter { $0.name == "swift-frontend" }
        suite.expect(codeMembers.first(where: { $0.name == "swift-frontend" })?.count == swiftRows.count,
                     "a grouped process row counts helpers that share an executable name")
        suite.expect(codeMembers.map(\.name) == ["clang", "swift-frontend"],
                     "a grouped process row lists its helper names heaviest first")

        let tied = ProcessUsageGrouping.grouped([ProcessUsage(pid: 9, name: "b", value: 5),
                                                 ProcessUsage(pid: 3, name: "a", value: 5)],
                                                owner: { $0 },
                                                displayName: { _, fallback in fallback })
        suite.expect(tied.map(\.pid) == [3, 9],
                     "grouped process rows with equal values keep a stable order")
        suite.expect(tied.first?.name == "a",
                     "a grouped process row falls back to the helper's own name")
    }

    private static func knownActivityChecks(_ suite: TestSuite) {
        suite.expect(HealthKnownActivity.activity(forProcessName: "swift-frontend") == .compiling
                        && HealthKnownActivity.activity(forProcessName: "mds_stores") == .spotlightIndexing
                        && HealthKnownActivity.activity(forProcessName: "backupd") == .timeMachineBackup,
                     "known activity recognises common executables by exact name")
        suite.expect(HealthKnownActivity.activity(forProcessName: "Creative Cloud Content Manager.node") == nil
                        && HealthKnownActivity.activity(forProcessName: "nodemon") == nil
                        && HealthKnownActivity.activity(forProcessName: "Node") == nil,
                     "known activity never matches a name that only contains a tool's name")
        suite.expect(HealthKnownActivity.activity(forProcessName: "com.docker.backend") == .virtualMachine
                        && HealthKnownActivity.activity(forProcessName: "qemu-system-aarch64") == .virtualMachine,
                     "known activity recognises executable families by prefix")
        suite.expect(HealthKnownActivity.activity(forProcessName: "kernel_task") == nil,
                     "known activity leaves out names ps cannot list without root")

        let reachable = Set(HealthKnownActivity.exactNames.values)
            .union(HealthKnownActivity.namePrefixes.map(\.activity))
        suite.expect(reachable == Set(HealthActivity.allCases),
                     "every health activity is reachable from at least one executable name")
    }

    private static func sightingChecks(_ suite: TestSuite) {
        let code = ProcessUsage(pid: 1, name: "Code", value: 9_000_000_000,
                                members: [ProcessMember(name: "swift-frontend", count: 6),
                                          ProcessMember(name: "Code Helper", count: 3),
                                          ProcessMember(name: "clang", count: 2)])
        let codeByCPU = ProcessUsage(pid: 1, name: "Code", value: 80,
                                     members: [ProcessMember(name: "swift-frontend", count: 6)])
        let spotlight = ProcessUsage(pid: 7, name: "mds_stores", value: 40,
                                     members: [ProcessMember(name: "mds_stores", count: 1)])
        var snapshot = HealthSignalSnapshot()
        snapshot.topMemory = [code]
        snapshot.topCPU = [codeByCPU, spotlight]
        let sightings = snapshot.activitySightings

        suite.expect(sightings.count == 2,
                     "an activity inside one app is reported once across memory and CPU rows")
        suite.expect(sightings.first?.activity == .compiling
                        && sightings.first?.processCount == code.members
                            .filter { HealthKnownActivity.activity(forProcessName: $0.name) == .compiling }
                            .reduce(0) { $0 + $1.count },
                     "an activity sighting counts every process of that activity in the app")
        suite.expect(sightings.first?.appValue == code.value,
                     "an activity sighting prefers the memory row, which carries the size to quote")
        suite.expect(sightings.last?.activity == .spotlightIndexing && sightings.last?.appName == "mds_stores",
                     "an activity seen only among CPU rows is still reported")
        suite.expect(HealthSignalSnapshot().activitySightings.isEmpty,
                     "an empty health snapshot reports no activity")
    }

    private static func processSourceChecks(_ suite: TestSuite) {
        let path = "Sources/PowerTools/Services/SystemMonitor/ProcessUsageService.swift"
        let source = (try? String(contentsOfFile: path, encoding: .utf8)) ?? ""
        suite.expect(!source.isEmpty, "process usage source is readable for its privacy checks")
        let code = source.components(separatedBy: "\n")
            .filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//") }
            .joined(separator: "\n")
        suite.expect(code.contains("\"pid,rss,comm\""),
                     "process usage reads executable names from ps")
        suite.expect(!code.contains("args") && !code.contains(",command"),
                     "process usage never reads command-line arguments")
        suite.expect(code.contains("members: row.members"),
                     "reconciled CPU rows keep the helper names they were grouped from")
    }
}
