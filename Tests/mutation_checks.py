#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 Vorssaint
# Copyright (C) 2026 PowerTools contributors

"""Verify that selected real regressions fail their existing tests.

Each mutation runs in a temporary copy and must fail an assertion with the
expected diagnostic. Compiler errors, timeouts and unrelated failures do not
count as detection. The working checkout and its build cache stay untouched.
"""
from pathlib import Path
import os
import signal
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]

MUTATIONS = [
    ("invalid numeric result", "harness", "Tests/TestSuite.swift",
     "actual.isFinite && expected.isFinite && tol.isFinite && tol >= 0\n                   && abs(actual - expected) <= tol",
     "!(abs(actual - expected) > tol)", "every invalid numeric comparison fails"),
    ("invalid saved zoom", "core", "Sources/PowerTools/Services/QuickTools/ScreenshotSupport.swift",
     "guard requested.isFinite else { return 1 }", "guard requested.isFinite else { return requested }",
     "an invalid saved magnifier zoom falls back safely"),
    ("missing recording action", "launcher", "Sources/PowerTools/Services/QuickTools/QuickLauncherService.swift",
     "                ScreenRecorderService.shared.toggle()", "                // ScreenRecorderService.shared.toggle()",
     "screenRecorder executes the intended action exactly once"),
    ("incorrect recording icon", "launcher", "Sources/PowerTools/UI/QuickLauncher/QuickLauncherView.swift",
     'case .screenRecorder: return recorder.isRecording ? "stop.circle" : "record.circle"',
     'case .screenRecorder: return "record.circle"', "an active recording tile offers stopping"),
    ("missing translation", "localization", "Sources/PowerTools/Core/FeatureStrings.swift",
     'shortcutHint: "Clique numa linha para colar no app anterior. ⌘+clique seleciona várias; ⌘C copia sem colar."',
     'shortcutHint: ""', "clipboard/pt-BR: missing text in shortcutHint"),
    ("unsafe argument comparison", "harness", "Tests/LocalizationTests.swift",
     "actual?.arguments == expected?.arguments",
     "actual?.arguments.values.sorted() == expected?.arguments.values.sorted()",
     "localization validation detects missing text and unsafe argument swaps"),
    ("overwrite unreadable notes", "storage", "Sources/PowerTools/Services/QuickTools/ScratchpadStore.swift",
     "        guard canSave else { return false }", "        // guard canSave else { return false }",
     "damaged scratchpad blocks subsequent saves of empty and nonempty documents"),
    ("empty plan becomes runnable", "ai-harness", "Sources/PowerTools/Services/AI/AIPlanValidator.swift",
     "guard !plan.steps.isEmpty else { return .rejected([.emptyPlan]) }",
     "guard !plan.steps.isEmpty else { return .valid(ValidatedPlan(plan: plan)) }",
     "an agent cannot execute an empty plan"),
    ("plan approval covers destructive steps", "ai-harness", "Sources/PowerTools/Services/AI/AIPlanValidator.swift",
     "let needsStepApproval = risk > .reversible",
     "let needsStepApproval = risk > .destructive",
     "a plan approval never satisfies a destructive step"),
    ("plan approval ignores its steps", "ai-harness", "Sources/PowerTools/Services/AI/AIPlanValidator.swift",
     "if !needsStepApproval && approvals.contains(.plan(revision: plan.revision, steps: plan.steps)) { return nil }",
     "if !needsStepApproval && approvals.contains(where: { if case .plan(let revision, _) = $0 { return revision == plan.revision }; return false }) { return nil }",
     "changing a step after approval voids the plan approval"),
    ("permission-blocked row treated as ready", "ai-harness", "Sources/PowerTools/Services/AI/AIPlanValidator.swift",
     "case .ready?:",
     "case .ready?, .needsPermission?:",
     "an approval cannot substitute for a macOS permission"),
    ("number range ignored", "ai-harness", "Sources/PowerTools/Services/AI/AIHarnessContracts.swift",
     "return range.contains(number) ? id : nil",
     "return id",
     "an out-of-range number is rejected"),
    ("keep-awake range drifts from its row", "ai-harness", "Sources/PowerTools/Services/AI/AIActionRegistry.swift",
     'reversible("action.keepAwake", .integer(1...480, optional: true)),',
     'reversible("action.keepAwake", .integer(1...600, optional: true)),',
     "registered number ranges match the Command Bar row"),
    ("confirmed row registered as reversible", "ai-harness", "Sources/PowerTools/Services/AI/AIActionRegistry.swift",
     '        reversible("action.darkMode"),',
     '        reversible("action.darkMode"),\n        reversible("action.emptyTrash"),',
     "an action the Command Bar confirms is never registered below destructive"),
    ("catalog row left undecided", "ai-harness", "Tests/AIActionRegistryTests.swift",
     '"action.wifi": interrupts,',
     '',
     "every Command Bar row is registered for AI or excluded with a reason"),
    ("expired lease still runs", "ai-harness", "Sources/PowerTools/Services/AI/AIPlanValidator.swift",
     "if now >= lease.expiresAt { violations.append(.leaseExpired) }",
     "if now > lease.expiresAt.addingTimeInterval(3600) { violations.append(.leaseExpired) }",
     "a lease stops at its deadline"),
    ("lease ignored for registered actions", "ai-harness", "Sources/PowerTools/Services/AI/AIPlanValidator.swift",
     "guard lease.allowedActionIDs.contains(action.id) else {",
     "guard true else {",
     "a registered, approved action outside the lease is rejected"),
    ("contract names a missing check", "ai-harness", "docs/AI-HARNESS.md",
     "`an agent cannot execute an empty plan`",
     "`an agent can execute an empty plan`",
     "every guarantee in AI-HARNESS.md names a check that exists"),
    ("activity matched by substring", "health-coach",
     "Sources/PowerTools/Services/HealthCoach/HealthKnownActivity.swift",
     "if let activity = exactNames[name] { return activity }",
     "if let activity = exactNames.first(where: { name.contains($0.key) })?.value { return activity }",
     "known activity never matches a name that only contains a tool's name"),
    ("helper count lost", "health-coach",
     "Sources/PowerTools/Services/SystemMonitor/ProcessUsageGrouping.swift",
     "entry.count += 1", "entry.count = 1",
     "a grouped process row counts helpers that share an executable name"),
    ("reconciled rows drop helpers", "health-coach",
     "Sources/PowerTools/Services/SystemMonitor/ProcessUsageService.swift",
     "value: MetricFormat.boundedPercentage(row.value * scale),\n                         members: row.members)",
     "value: MetricFormat.boundedPercentage(row.value * scale))",
     "reconciled CPU rows keep the helper names they were grouped from"),
    ("charging battery still alerts", "health-coach",
     "Sources/PowerTools/Services/HealthCoach/HealthFindingDetector.swift",
     "if snapshot.hasInternalBattery, !snapshot.batteryIsCharging,",
     "if snapshot.hasInternalBattery,",
     "a low battery that is charging is not a finding"),
    ("swap growth ignores the time gap", "health-coach",
     "Sources/PowerTools/Services/HealthCoach/HealthFindingDetector.swift",
     "capturedAt - previousCapturedAt >= HealthFindingThresholds.swapGrowthWindowSeconds,",
     "capturedAt - previousCapturedAt >= 0,",
     "the same growth over too short a gap is not evaluated as a finding"),
    ("disk-low picks the wrong device", "health-coach",
     "Sources/PowerTools/Services/HealthCoach/HealthFindingDetector.swift",
     ".min { Double($0.freeBytes) / Double($0.totalBytes) < Double($1.freeBytes) / Double($1.totalBytes) }",
     ".max { Double($0.freeBytes) / Double($0.totalBytes) < Double($1.freeBytes) / Double($1.totalBytes) }",
     "the disk-low finding names the specific device nearest its threshold"),
    ("header narrates without the shared template", "health-coach",
     "Sources/PowerTools/UI/MenuPanel/MenuPanelView.swift",
     "return HealthNarrationTemplate.headline(for: finding, strings: l10n.s,\n"
     "                                                healthCoach: FeatureStrings.healthCoach(l10n.language))",
     "return l10n.s.healthEverythingGood",
     "the header's status line is worded by the shared template, not its own copy of the sentences"),
    ("sustained gate skips the hold", "health-coach",
     "Sources/PowerTools/Services/Metrics/SustainedAlertGate.swift",
     "return readAt - since >= Self.sustainedSeconds",
     "return true",
     "critical memory pressure short of the sustained window still does not fire"),
    ("journal never ages out", "health-coach",
     "Sources/PowerTools/Services/HealthCoach/HealthActivityJournal.swift",
     "entries.removeAll { $0.occurredAt < cutoff }",
     "_ = cutoff",
     "an entry older than the age window is pruned even without a new event arriving"),
    ("journal cap drops the newest entries", "health-coach",
     "Sources/PowerTools/Services/HealthCoach/HealthActivityJournal.swift",
     "entries.removeLast(entries.count - Self.maximumEntries)",
     "entries.removeFirst(entries.count - Self.maximumEntries)",
     "the entry cap keeps the newest events, not the oldest"),
    ("noteFindings always republishes", "health-coach",
     "Sources/PowerTools/Services/HealthCoach/HealthActivityJournalService.swift",
     "guard findings != latestFindings else { return }",
     "// guard findings != latestFindings else { return }",
     "noteFindings skips its @Published write when nothing changed, so an observer reading it cannot re-trigger itself forever"),
    ("header gate mutates on every read", "health-coach",
     "Sources/PowerTools/UI/MenuPanel/MenuPanelView.swift",
     "if let cachedFindingsReadAt, cachedFindingsReadAt == snapshot.capturedAt {\n            return cachedFindings\n        }",
     "if false {\n            return cachedFindings\n        }",
     "the header only mutates its gate once per real monitor tick, not once per read of findings"),
    ("chrome height reverts to a flat constant", "health-coach",
     "Sources/PowerTools/UI/MenuPanel/MenuPanelView.swift",
     "return 24 + 12 + measuredHeaderHeight + backRow + bannerHeight",
     "return 90 + backRow + bannerHeight",
     "the panel's chrome height budget uses the header's measured height, not a flat constant sized for its compact state"),
    ("expanded detail loses its own collapse control", "health-coach",
     "Sources/PowerTools/UI/HealthCoach/HealthCoachDetailView.swift",
     "        VStack(alignment: .leading, spacing: 10) {\n            collapseRow\n            findingsSection\n",
     "        VStack(alignment: .leading, spacing: 10) {\n            findingsSection\n",
     "the collapse row is actually shown, not just defined and forgotten"),
    ("mode off still calls the model", "health-coach",
     "Sources/PowerTools/Services/HealthCoach/HealthCoachTriggerPolicy.swift",
     "guard settings.mode != .off else { return .useTemplate(.off) }",
     "guard settings.mode != .onDemand else { return .useTemplate(.off) }",
     "mode Off refuses even an explicit Explain press"),
    ("critical memory pressure ignores the local provider", "health-coach",
     "Sources/PowerTools/Services/HealthCoach/HealthCoachTriggerPolicy.swift",
     "if system.memoryPressureCritical, providerBoundary == .local {",
     "if false, providerBoundary == .local {",
     "Decision D4: critical memory pressure refuses the on-device or a local server provider, even via Explain's cooldown bypass"),
    ("daily cap off by one", "health-coach",
     "Sources/PowerTools/Services/HealthCoach/HealthCoachTriggerPolicy.swift",
     "if ledger.callCount(sinceLast: 86_400, asOf: now) >= settings.maxCallsPerDay {",
     "if ledger.callCount(sinceLast: 86_400, asOf: now) > settings.maxCallsPerDay {",
     "the daily cap refuses even an explicit Explain press"),
    ("hourly cap off by one", "health-coach",
     "Sources/PowerTools/Services/HealthCoach/HealthCoachTriggerPolicy.swift",
     "if ledger.callCount(sinceLast: 3_600, asOf: now) >= settings.maxCallsPerHour {",
     "if ledger.callCount(sinceLast: 3_600, asOf: now) > settings.maxCallsPerHour {",
     "the hourly cap refuses even an explicit Explain press"),
    ("low power deferral removed", "health-coach",
     "Sources/PowerTools/Services/HealthCoach/HealthCoachTriggerPolicy.swift",
     "if system.lowPowerModeEnabled { return .useTemplate(.lowPowerMode) }",
     "// if system.lowPowerModeEnabled { return .useTemplate(.lowPowerMode) }",
     "Low Power Mode defers an automatic call"),
    ("thermal deferral removed", "health-coach",
     "Sources/PowerTools/Services/HealthCoach/HealthCoachTriggerPolicy.swift",
     "if system.thermalThrottling { return .useTemplate(.thermalThrottling) }",
     "// if system.thermalThrottling { return .useTemplate(.thermalThrottling) }",
     "thermal throttling defers an automatic call"),
    ("change severity gate ignored", "health-coach",
     "Sources/PowerTools/Services/HealthCoach/HealthCoachTriggerPolicy.swift",
     "guard let mostSevere = findings.map(\\.severity).max(), mostSevere >= settings.changeSeverityThreshold else {",
     "guard let mostSevere = findings.map(\\.severity).max(), true else {",
     "when-something-changes mode ignores findings below its chosen severity"),
    ("unchanged finding set skips the cache", "health-coach",
     "Sources/PowerTools/Services/HealthCoach/HealthCoachTriggerPolicy.swift",
     "        if kinds == ledger.lastExplainedKinds { return .useCache }\n        return now.timeIntervalSince(lastCallAt) >= findingKindCooldown ? .callModel : .useTemplate(.cooldownActive)",
     "        if false { return .useCache }\n        return now.timeIntervalSince(lastCallAt) >= findingKindCooldown ? .callModel : .useTemplate(.cooldownActive)",
     "an unchanged finding set reuses the cached explanation instead of calling again"),
    ("per-finding-kind cooldown ignored", "health-coach",
     "Sources/PowerTools/Services/HealthCoach/HealthCoachTriggerPolicy.swift",
     "return now.timeIntervalSince(lastCallAt) >= findingKindCooldown ? .callModel : .useTemplate(.cooldownActive)",
     "return .callModel",
     "a changed finding set still waits out the per-finding-kind cooldown before calling again"),
    ("scheduled interval ignored", "health-coach",
     "Sources/PowerTools/Services/HealthCoach/HealthCoachTriggerPolicy.swift",
     "return now.timeIntervalSince(lastCallAt) >= interval ? .callModel : .useTemplate(.cooldownActive)",
     "return .callModel",
     "scheduled mode will not call again before its chosen interval has passed, even for a new finding"),
]


def run(directory, arguments):
    process = subprocess.Popen(["./build.sh", *arguments], cwd=directory,
                               stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                               text=True, start_new_session=True)
    try:
        output, _ = process.communicate(timeout=600)
    except subprocess.TimeoutExpired:
        os.killpg(process.pid, signal.SIGTERM)
        process.communicate()
        raise RuntimeError("Mutation run timed out; this is not a detected regression")
    return process.returncode, output


def main():
    with tempfile.TemporaryDirectory(prefix="pwrt-mutation-") as temporary:
        directory = Path(temporary)
        # APFS clones keep the snapshot cheap and preserve timestamps so the
        # compiler can reuse unaffected objects after the baseline build.
        tracked = subprocess.check_output(["git", "ls-files", "-z"], cwd=ROOT).decode().split("\0")
        entries = sorted({path.split("/")[0] for path in tracked if path})
        for name in entries:
            subprocess.run(["/bin/cp", "-cRp", str(ROOT / name), str(directory / name)], check=True)
        for name in ["objects/tests", "generated-tests", "metrics-tests"]:
            source = ROOT / "build" / name
            if source.exists():
                target = directory / "build" / name
                target.parent.mkdir(parents=True, exist_ok=True)
                subprocess.run(["/bin/cp", "-cRp", str(source), str(target)], check=True)

        print("Checking the unmodified baseline…", flush=True)
        status, output = run(directory, ["--test"])
        if status != 0 or "TESTS OK" not in output:
            raise RuntimeError("Baseline failed:\n" + output[-12000:])
        for name, group, relative, before, after, diagnostic in MUTATIONS:
            path = directory / relative
            original = path.read_text()
            if original.count(before) != 1:
                raise RuntimeError(f"Mutation fixture needs updating: {name}")
            print(f"Checking: {name}…", flush=True)
            try:
                path.write_text(original.replace(before, after))
                status, output = run(directory, ["--test-suite=" + group])
                if status != 1 or "TESTS FAILED" not in output or diagnostic not in output:
                    raise RuntimeError(f"Mutation was not caught by its intended assertion: {name}\n{output[-12000:]}")
                print(f"DETECTED: {name}", flush=True)
            finally:
                path.write_text(original)
        print(f"MUTATION CHECKS OK ({len(MUTATIONS)} regressions detected)", flush=True)


if __name__ == "__main__":
    main()
