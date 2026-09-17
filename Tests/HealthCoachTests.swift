// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 PowerTools AI contributors

import Foundation

enum HealthCoachTests {
    static func run(_ suite: TestSuite) {
        groupingChecks(suite)
        knownActivityChecks(suite)
        sightingChecks(suite)
        processSourceChecks(suite)
        thresholdChecks(suite)
        detectorChecks(suite)
        orderingChecks(suite)
        templateChecks(suite)
        headerWiringChecks(suite)
        registrationChecks(suite)
        journalChecks(suite)
        journalTemplateChecks(suite)
        journalWiringChecks(suite)
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

    private static func thresholdChecks(_ suite: TestSuite) {
        suite.expect(Defaults.registeredDefaults[DefaultsKey.healthCoachMemoryHogPercent] as? Int == 30,
                     "the memory-hog threshold registers a default so Settings never reads an unset key")

        let defaults = UserDefaults.standard
        let keys = [DefaultsKey.monitorAlertCPUThreshold, DefaultsKey.healthCoachMemoryHogPercent,
                   DefaultsKey.monitorAlertDiskFreePercent, DefaultsKey.monitorAlertBatteryPercent]
        let saved = keys.map { defaults.object(forKey: $0) }
        defer {
            for (key, value) in zip(keys, saved) {
                if let value { defaults.set(value, forKey: key) } else { defaults.removeObject(forKey: key) }
            }
        }

        for key in keys { defaults.removeObject(forKey: key) }
        let fallbacks = HealthFindingThresholds.sanitized(defaults: defaults)
        suite.expect(fallbacks == HealthFindingThresholds(cpuPercent: 90, memoryHogPercent: 30,
                                                           diskFreePercent: 10, batteryPercent: 15),
                     "an unset threshold falls back to the same numbers Monitor Alerts uses")

        defaults.set(999, forKey: DefaultsKey.monitorAlertCPUThreshold)
        suite.expect(HealthFindingThresholds.sanitized(defaults: defaults).cpuPercent == 90,
                     "an out-of-range CPU threshold falls back rather than detecting on a nonsense number")

        defaults.set(70, forKey: DefaultsKey.monitorAlertCPUThreshold)
        defaults.set(50, forKey: DefaultsKey.healthCoachMemoryHogPercent)
        defaults.set(20, forKey: DefaultsKey.monitorAlertDiskFreePercent)
        defaults.set(30, forKey: DefaultsKey.monitorAlertBatteryPercent)
        suite.expect(HealthFindingThresholds.sanitized(defaults: defaults)
                        == HealthFindingThresholds(cpuPercent: 70, memoryHogPercent: 50,
                                                   diskFreePercent: 20, batteryPercent: 30),
                     "a threshold Settings -> Monitor -> Alerts writes is read back exactly, the same key both use")
    }

    private static func detectorChecks(_ suite: TestSuite) {
        let thresholds = HealthFindingThresholds()

        // Battery
        var battery = HealthSignalSnapshot()
        battery.hasInternalBattery = true
        battery.batteryChargePercent = 10
        var noGates = HealthFindingGates()
        suite.expect(HealthFindingDetector.findings(for: battery, previous: nil, gates: &noGates, thresholds: thresholds)
                        .contains(.batteryLow(chargePercent: 10, thresholdPercent: 15)),
                     "a low, unplugged battery is a finding")
        battery.batteryIsCharging = true
        suite.expect(!HealthFindingDetector.findings(for: battery, previous: nil, gates: &noGates, thresholds: thresholds)
                        .contains(where: { if case .batteryLow = $0 { return true }; return false }),
                     "a low battery that is charging is not a finding")

        // Thermal
        var thermal = HealthSignalSnapshot()
        thermal.thermalPressure = .moderate
        suite.expect(HealthFindingDetector.findings(for: thermal, previous: nil, gates: &noGates, thresholds: thresholds).isEmpty,
                     "moderate thermal pressure, which is not yet throttling, is not a finding")
        thermal.thermalPressure = .heavy
        let heavyFindings = HealthFindingDetector.findings(for: thermal, previous: nil, gates: &noGates, thresholds: thresholds)
        suite.expect(heavyFindings.count == 1 && heavyFindings.first?.severity == .notable,
                     "throttling below critical is a notable finding, not a critical one")
        thermal.thermalPressure = .critical
        suite.expect(HealthFindingDetector.findings(for: thermal, previous: nil, gates: &noGates, thresholds: thresholds)
                        .first?.severity == .critical,
                     "critical thermal pressure is a critical finding")

        // Memory pressure needs to hold for the sustained window
        var memory = HealthSignalSnapshot()
        memory.memoryPressure = .critical
        memory.memoryUsedBytes = 12_000_000_000
        memory.memoryTotalBytes = 16_000_000_000
        memory.swapUsedBytes = 2_000_000_000
        memory.topMemory = [ProcessUsage(pid: 1, name: "Heavy", value: 8_000_000_000)]
        var memoryGates = HealthFindingGates()
        memory.capturedAt = 0
        suite.expect(!HealthFindingDetector.findings(for: memory, previous: nil, gates: &memoryGates, thresholds: thresholds)
                        .contains(where: { if case .memoryPressureCritical = $0 { return true }; return false }),
                     "a single critical memory reading does not fire before it has held")
        memory.capturedAt = 6
        suite.expect(!HealthFindingDetector.findings(for: memory, previous: nil, gates: &memoryGates, thresholds: thresholds)
                        .contains(where: { if case .memoryPressureCritical = $0 { return true }; return false }),
                     "critical memory pressure short of the sustained window still does not fire")
        memory.capturedAt = 13
        let sustainedMemory = HealthFindingDetector.findings(for: memory, previous: nil, gates: &memoryGates, thresholds: thresholds)
        suite.expect(sustainedMemory.contains { finding in
            if case .memoryPressureCritical(let used, let total, let swap, let topApps) = finding {
                return used == memory.memoryUsedBytes && total == memory.memoryTotalBytes
                    && swap == memory.swapUsedBytes && topApps == memory.topMemory
            }
            return false
        }, "critical memory pressure held for the sustained window fires with the readings that proved it")
        memory.memoryPressure = .normal
        memory.capturedAt = 14
        suite.expect(!HealthFindingDetector.findings(for: memory, previous: nil, gates: &memoryGates, thresholds: thresholds)
                        .contains(where: { if case .memoryPressureCritical = $0 { return true }; return false }),
                     "memory pressure returning to normal clears the sustained gate immediately")

        // Disk: the device closest to its threshold is named, not just "some disk"
        let full = HealthDiskEvidence(name: "Data", freeBytes: 1_000_000_000, totalBytes: 500_000_000_000)
        // Also below the threshold (8% free), so a wrong pick between two
        // qualifying devices is what this test actually exercises.
        let almostFull = HealthDiskEvidence(name: "Almost", freeBytes: 40_000_000_000, totalBytes: 500_000_000_000)
        let roomy = HealthDiskEvidence(name: "Backup", freeBytes: 400_000_000_000, totalBytes: 500_000_000_000)
        let tiny = HealthDiskEvidence(name: "Recovery", freeBytes: 100_000_000, totalBytes: 4_000_000_000)
        var disk = HealthSignalSnapshot()
        disk.diskDevices = [roomy, almostFull, full, tiny]
        let diskFindings = HealthFindingDetector.findings(for: disk, previous: nil, gates: &noGates, thresholds: thresholds)
        suite.expect(diskFindings.contains(.diskLow(device: full, thresholdPercent: 10)),
                     "the disk-low finding names the specific device nearest its threshold")
        suite.expect(!diskFindings.contains(where: { if case .diskLow(let device, _) = $0 { return device.name == "Almost" }; return false }),
                     "a qualifying but less urgent device is not the one named")
        suite.expect(!diskFindings.contains(where: { if case .diskLow(let device, _) = $0 { return device.name == "Recovery" }; return false }),
                     "a device under the 10 GB floor is never a disk-low finding")

        // Memory hog
        var hog = HealthSignalSnapshot()
        hog.memoryTotalBytes = 16_000_000_000
        hog.topMemory = [ProcessUsage(pid: 2, name: "Chrome", value: 4_000_000_000)]
        suite.expect(HealthFindingDetector.findings(for: hog, previous: nil, gates: &noGates, thresholds: thresholds)
                        .contains(.memoryHog(app: hog.topMemory[0], percentOfTotal: 25, thresholdPercent: 30)) == false,
                     "an app under the memory-hog threshold is not a finding")
        hog.topMemory = [ProcessUsage(pid: 2, name: "Chrome", value: 6_000_000_000)]
        suite.expect(HealthFindingDetector.findings(for: hog, previous: nil, gates: &noGates, thresholds: thresholds)
                        .contains(.memoryHog(app: hog.topMemory[0], percentOfTotal: 37.5, thresholdPercent: 30)),
                     "an app over the memory-hog threshold of total RAM is a finding")

        // Swap growth needs both real growth and a genuine time gap
        var swapBefore = HealthSignalSnapshot()
        swapBefore.swapUsedBytes = 500_000_000
        swapBefore.capturedAt = 0
        var swapAfter = swapBefore
        swapAfter.swapUsedBytes = 3_000_000_000
        swapAfter.capturedAt = 601
        suite.expect(HealthFindingDetector.findings(for: swapAfter, previous: swapBefore, gates: &noGates, thresholds: thresholds)
                        .contains(.swapGrowth(beforeBytes: 500_000_000, afterBytes: 3_000_000_000, windowSeconds: 601)),
                     "swap growing past the threshold over the full window is a finding")
        var tooSoon = swapBefore
        tooSoon.capturedAt = 0
        var afterTooSoon = swapAfter
        afterTooSoon.capturedAt = 60
        suite.expect(!HealthFindingDetector.findings(for: afterTooSoon, previous: tooSoon, gates: &noGates, thresholds: thresholds)
                        .contains(where: { if case .swapGrowth = $0 { return true }; return false }),
                     "the same growth over too short a gap is not evaluated as a finding")
        var smallGrowth = swapBefore
        smallGrowth.swapUsedBytes = 1_200_000_000
        smallGrowth.capturedAt = 700
        suite.expect(!HealthFindingDetector.findings(for: smallGrowth, previous: swapBefore, gates: &noGates, thresholds: thresholds)
                        .contains(where: { if case .swapGrowth = $0 { return true }; return false }),
                     "swap growth under 2 GB across the window is not a finding")

        // CPU needs to hold for the sustained window, exactly like Monitor Alerts' own gate
        var cpu = HealthSignalSnapshot()
        cpu.cpuUsage = 0.95
        cpu.topCPU = [ProcessUsage(pid: 3, name: "Xcode", value: 95)]
        var cpuGates = HealthFindingGates()
        cpu.cpuUsageReadAt = 0
        suite.expect(!HealthFindingDetector.findings(for: cpu, previous: nil, gates: &cpuGates, thresholds: thresholds)
                        .contains(where: { if case .cpuSustained = $0 { return true }; return false }),
                     "a single high CPU reading does not fire before it has held")
        cpu.cpuUsageReadAt = 13
        suite.expect(HealthFindingDetector.findings(for: cpu, previous: nil, gates: &cpuGates, thresholds: thresholds)
                        .contains(.cpuSustained(usage: 0.95, thresholdPercent: 90, topApps: cpu.topCPU)),
                     "CPU usage held over the threshold for the sustained window fires")

        // Known activity and update availability pass straight through
        var activity = HealthSignalSnapshot()
        activity.topCPU = [ProcessUsage(pid: 4, name: "Code", value: 50,
                                        members: [ProcessMember(name: "swift-frontend", count: 3)])]
        suite.expect(HealthFindingDetector.findings(for: activity, previous: nil, gates: &noGates, thresholds: thresholds)
                        .contains(.knownActivity(activity.activitySightings[0])),
                     "a recognised activity in the top rows is a finding with no gate to hold")
        var update = HealthSignalSnapshot()
        update.updateAvailable = true
        suite.expect(HealthFindingDetector.findings(for: update, previous: nil, gates: &noGates, thresholds: thresholds)
                        .contains(.updateAvailable),
                     "an available update is a finding")
    }

    private static func orderingChecks(_ suite: TestSuite) {
        let findings: [HealthFinding] = [.updateAvailable, .knownActivity(HealthActivitySighting(
            appPID: 1, appName: "Code", activity: .compiling, processCount: 2, appValue: 1,
            valueIsMemoryBytes: true)),
            .batteryLow(chargePercent: 5, thresholdPercent: 15),
            .thermal(level: .critical, topCPUApp: nil)]
        suite.expect(findings.orderedByUrgency.map(\.severity) == [.critical, .critical, .info, .info],
                     "findings are ordered most urgent first regardless of the order they were detected in")
        suite.expect(findings.orderedByUrgency.first == .batteryLow(chargePercent: 5, thresholdPercent: 15),
                     "battery low outranks even a critical thermal finding, matching the header's original priority")

        let tiedPriority: [HealthFinding] = [
            .knownActivity(HealthActivitySighting(appPID: 1, appName: "A", activity: .compiling,
                                                  processCount: 1, appValue: 1, valueIsMemoryBytes: true)),
            .knownActivity(HealthActivitySighting(appPID: 2, appName: "B", activity: .rustBuild,
                                                  processCount: 1, appValue: 1, valueIsMemoryBytes: true)),
        ]
        suite.expect(tiedPriority.orderedByUrgency == tiedPriority,
                     "findings of equal priority keep the order the detector produced them in")
    }

    private static func templateChecks(_ suite: TestSuite) {
        let s = Strings.enUS
        let hc = HealthCoachStrings.enUS

        func headline(_ finding: HealthFinding) -> String {
            HealthNarrationTemplate.headline(for: finding, strings: s, healthCoach: hc)
        }

        suite.expect(headline(.batteryLow(chargePercent: 5, thresholdPercent: 15)) == s.healthBatteryCriticallyLow,
                     "the battery-low headline reuses the header's existing, translated sentence")
        suite.expect(headline(.thermal(level: .critical, topCPUApp: nil)) == s.healthThermalCritical,
                     "critical thermal keeps the header's existing sentence")
        suite.expect(headline(.thermal(level: .heavy, topCPUApp: nil)) == hc.thermalThrottling,
                     "throttling below critical gets its own, less alarming sentence")
        suite.expect(headline(.memoryPressureCritical(usedBytes: 0, totalBytes: nil, swapBytes: nil, topApps: []))
                        == s.healthMemoryCritical,
                     "critical memory pressure keeps the header's existing sentence")
        suite.expect(headline(.memoryPressureWarning(usedBytes: 0, totalBytes: nil, swapBytes: nil, topApps: []))
                        == hc.memoryPressureWarning,
                     "memory pressure below critical gets its own sentence, distinct from the critical one")
        suite.expect(headline(.diskLow(device: HealthDiskEvidence(name: "Data", freeBytes: 0, totalBytes: 0),
                                       thresholdPercent: 10)) == s.healthDiskCriticallyLow,
                     "disk-low keeps the header's existing sentence")
        suite.expect(headline(.updateAvailable) == s.updateBannerTitle,
                     "update-available keeps the header's existing sentence")

        let hog = ProcessUsage(pid: 1, name: "Chrome", value: 6_000_000_000)
        suite.expect(headline(.memoryHog(app: hog, percentOfTotal: 37.5, thresholdPercent: 30))
                        == String(format: hc.memoryHogFormat, "Chrome", 38),
                     "the memory-hog headline names the app and its rounded share of RAM, nothing invented")

        suite.expect(headline(.swapGrowth(beforeBytes: 500_000_000, afterBytes: 3_000_000_000, windowSeconds: 600))
                        == String(format: hc.swapGrowthFormat, MetricFormat.bytes(3_000_000_000), MetricFormat.bytes(500_000_000)),
                     "the swap-growth headline quotes both the before and after figures from its own evidence")

        let heavyApp = ProcessUsage(pid: 2, name: "Xcode", value: 95)
        suite.expect(headline(.cpuSustained(usage: 0.95, thresholdPercent: 90, topApps: [heavyApp]))
                        == String(format: hc.cpuSustainedFormat, "Xcode", 95),
                     "the sustained-CPU headline names the heaviest app from its own evidence")

        let memorySighting = HealthActivitySighting(appPID: 3, appName: "Code", activity: .compiling,
                                                    processCount: 6, appValue: 9_000_000_000, valueIsMemoryBytes: true)
        suite.expect(headline(.knownActivity(memorySighting))
                        == String(format: hc.activityWithMemoryFormat, "Code", hc.activityCompiling,
                                  MetricFormat.bytes(9_000_000_000)),
                     "a memory-based activity sighting quotes its footprint, matching PowerToys-style attribution")

        let cpuSighting = HealthActivitySighting(appPID: 4, appName: "node", activity: .javaScriptTooling,
                                                 processCount: 1, appValue: 42, valueIsMemoryBytes: false)
        suite.expect(headline(.knownActivity(cpuSighting))
                        == String(format: hc.activityWithCPUFormat, "node", hc.activityJavaScriptTooling, 42),
                     "a CPU-only activity sighting quotes CPU percent, never mistaking it for a memory figure")

        for activity in HealthActivity.allCases {
            suite.expect(!hc.phrase(for: activity).isEmpty, "every health activity has a template phrase: \(activity)")
        }
    }

    private static func headerWiringChecks(_ suite: TestSuite) {
        let path = "Sources/PowerTools/UI/MenuPanel/MenuPanelView.swift"
        let source = (try? String(contentsOfFile: path, encoding: .utf8)) ?? ""
        suite.expect(!source.isEmpty, "the menu panel source is readable for its wiring checks")
        suite.expect(source.contains("HealthFindingDetector.findings("),
                     "the header's status line is driven by the Health Coach detector, not a second copy of its rules")
        suite.expect(source.contains("HealthNarrationTemplate.headline("),
                     "the header's status line is worded by the shared template, not its own copy of the sentences")
        suite.expect(source.contains("gates: &healthGates"),
                     "the header threads a persistent gate across renders so a reading has to hold before it is shown")
    }

    private static func registrationChecks(_ suite: TestSuite) {
        suite.expect(AppFeature.healthCoach.group == .tools,
                     "Health Coach sits in the Tools group of the Features hub")
        suite.expect(AppFeature.healthCoach.enabledKeys.isEmpty,
                     "Health Coach is engaged simply by being installed, like other on-demand tools")
        suite.expect(AppFeature.healthCoach.permissions.isEmpty,
                     "Health Coach reads only data other already-permitted features already collect")
        suite.expect((AppFeature.availabilityDefaults[AppFeature.healthCoach.availabilityKey] as? Bool) == false,
                     "Health Coach ships uninstalled, matching every other feature added since aiTextActions")
        suite.expect(AppFeature.healthCoach.settingsDestination == FeatureSettingsDestination(.healthCoach),
                     "Health Coach has its own dedicated settings page, not a section on a shared one")
        suite.expect(FeatureVisibilitySupport.features(for: .healthCoach) == [.healthCoach],
                     "the health coach settings page is gated on the health coach feature alone")
        suite.expect(AppFeature.healthCoach.panelSearchDestination == .settings,
                     "health coach opens its dedicated settings page from panel search, not the panel itself")
        suite.expect(!FeatureStrings.healthCoach(.enUS).pageTitle.isEmpty
                        && !FeatureStrings.healthCoach(.enUS).hubDescription.isEmpty,
                     "health coach has a hub title and description distinct from its template strings")
    }

    private static func journalChecks(_ suite: TestSuite) {
        var journal = HealthActivityJournal()
        let now = Date()
        journal.record(.keepAwakeStarted(automatic: false), at: now)
        suite.expect(journal.entries.count == 1 && journal.entries.first?.event == .keepAwakeStarted(automatic: false),
                     "recording an event adds it, newest first")

        journal.record(.recordingStarted, at: now.addingTimeInterval(1))
        suite.expect(journal.entries.first?.event == .recordingStarted,
                     "a newer event sorts ahead of an older one")
        suite.expect(journal.entries.count == 2, "both distinct events are kept")

        var overflow = HealthActivityJournal()
        for index in 0..<(HealthActivityJournal.maximumEntries + 10) {
            overflow.record(.updateAvailable, at: now.addingTimeInterval(TimeInterval(index)))
        }
        suite.expect(overflow.entries.count == HealthActivityJournal.maximumEntries,
                     "the journal never grows past its entry cap")
        suite.expect(overflow.entries.first?.occurredAt == now.addingTimeInterval(
            TimeInterval(HealthActivityJournal.maximumEntries + 9)),
                     "the entry cap keeps the newest events, not the oldest")

        var aged = HealthActivityJournal()
        aged.record(.recordingStarted, at: now)
        aged.prune(now: now.addingTimeInterval(HealthActivityJournal.maximumAge + 1))
        suite.expect(aged.entries.isEmpty,
                     "an entry older than the age window is pruned even without a new event arriving")

        var fresh = HealthActivityJournal()
        fresh.record(.recordingStarted, at: now)
        fresh.prune(now: now.addingTimeInterval(HealthActivityJournal.maximumAge - 1))
        suite.expect(fresh.entries.count == 1,
                     "an entry inside the age window survives a prune")

        var cleared = HealthActivityJournal()
        cleared.record(.updateAvailable, at: now)
        cleared.clear()
        suite.expect(cleared.entries.isEmpty, "clearing the journal removes every entry")
    }

    private static func journalTemplateChecks(_ suite: TestSuite) {
        let hc = HealthCoachStrings.enUS

        func text(_ event: HealthJournalEvent) -> String {
            HealthJournalTemplate.text(for: event, strings: hc)
        }

        suite.expect(text(.keepAwakeStarted(automatic: false)) == hc.journalKeepAwakeStartedManual,
                     "a manual Keep Awake session reads differently from an automatic one")
        suite.expect(text(.keepAwakeStarted(automatic: true)) == hc.journalKeepAwakeStartedAutomatic,
                     "an automatic Keep Awake session says so")
        suite.expect(text(.keepAwakeEnded) == hc.journalKeepAwakeEnded, "keep awake ending has its own line")
        suite.expect(text(.recordingStarted) == hc.journalRecordingStarted, "recording starting has its own line")
        suite.expect(text(.recordingStopped(duration: 65))
                        == String(format: hc.journalRecordingStoppedFormat, "1m 5s"),
                     "a recording's duration is quoted from its own evidence, not recomputed elsewhere")
        suite.expect(text(.clipboardCaptured(sourceAppName: "Safari"))
                        == String(format: hc.journalClipboardCapturedFormat, "Safari"),
                     "a clipboard capture names only the source app, never content")
        suite.expect(text(.findingRaised(.batteryLow))
                        == String(format: hc.journalFindingRaisedFormat, hc.kindLabelBatteryLow),
                     "a raised finding names its own kind")
        suite.expect(text(.findingCleared(.diskLow))
                        == String(format: hc.journalFindingClearedFormat, hc.kindLabelDiskLow),
                     "a cleared finding names its own kind")

        for kind: HealthFinding.Kind in [.batteryLow, .thermal, .memoryPressureCritical, .diskLow,
                                         .memoryPressureWarning, .memoryHog(appPID: 1), .swapGrowth,
                                         .cpuSustained, .knownActivity(appPID: 1, activity: .compiling),
                                         .updateAvailable] {
            suite.expect(!hc.label(for: kind).isEmpty, "every finding kind has a journal label: \(kind)")
        }

        suite.expect(HealthFinding.batteryLow(chargePercent: 1, thresholdPercent: 2).kind == .batteryLow
                        && HealthFinding.memoryHog(app: ProcessUsage(pid: 9, name: "A", value: 1),
                                                   percentOfTotal: 1, thresholdPercent: 1).kind == .memoryHog(appPID: 9),
                     "a finding's kind strips its evidence but keeps what tells two instances apart")
        let compilingCode = HealthActivitySighting(appPID: 1, appName: "Code", activity: .compiling,
                                                   processCount: 1, appValue: 1, valueIsMemoryBytes: true)
        let buildingRust = HealthActivitySighting(appPID: 1, appName: "Code", activity: .rustBuild,
                                                  processCount: 1, appValue: 1, valueIsMemoryBytes: true)
        suite.expect(HealthFinding.knownActivity(compilingCode).kind != HealthFinding.knownActivity(buildingRust).kind,
                     "the same app running two different recognised activities are two different kinds")
    }

    private static func journalWiringChecks(_ suite: TestSuite) {
        let panelSource = (try? String(contentsOfFile: "Sources/PowerTools/UI/MenuPanel/MenuPanelView.swift",
                                       encoding: .utf8)) ?? ""
        suite.expect(!panelSource.isEmpty, "the menu panel source is readable for its journal wiring checks")
        suite.expect(panelSource.contains("healthJournal.noteFindings(result)"),
                     "the header's findings are relayed to the journal instead of it running a second detector")
        suite.expect(panelSource.contains("HealthCoachDetailPresentation.shared.toggle()"),
                     "the status line opens the shared detail presentation, not a view-local one")
        suite.expect(panelSource.contains("HealthCoachDetailView()"),
                     "the header actually shows the detail view when expanded")

        let appDelegateSource = (try? String(contentsOfFile: "Sources/PowerTools/App/AppDelegate.swift",
                                             encoding: .utf8)) ?? ""
        suite.expect(appDelegateSource.contains("HealthActivityJournalService.shared.clear()"),
                     "the in-memory-only journal is cleared on quit, never left for the next launch to find")
    }
}
