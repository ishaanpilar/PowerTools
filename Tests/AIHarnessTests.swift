// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint
// Copyright (C) 2026 PowerTools contributors

import Foundation

enum AIHarnessTests {
    static func run(_ suite: TestSuite) {
        let inspect = AIActionDescriptor(id: "system.inspect", risk: .readOnly, argument: .none, allowsBackgroundExecution: false)
        let arrange = AIActionDescriptor(id: "windows.arrange", risk: .reversible, argument: .none, allowsBackgroundExecution: false)
        let center = AIActionDescriptor(id: "windows.center", risk: .reversible, argument: .none, allowsBackgroundExecution: false)
        let cleanup = AIActionDescriptor(id: "cleaner.remove", risk: .destructive, argument: .none, allowsBackgroundExecution: false)
        let shareLink = AIActionDescriptor(id: "share.link", risk: .external, argument: .none, allowsBackgroundExecution: false)
        let adminToggle = AIActionDescriptor(id: "admin.toggle", risk: .privileged, argument: .none, allowsBackgroundExecution: false)
        let audioVolume = AIActionDescriptor(id: "audio.volume", risk: .reversible,
                                             argument: .integer(0...100, optional: false), allowsBackgroundExecution: false)
        let awakeStart = AIActionDescriptor(id: "awake.start", risk: .reversible,
                                            argument: .integer(1...480, optional: true), allowsBackgroundExecution: false)
        let audioOutput = AIActionDescriptor(id: "audio.output", risk: .reversible,
                                             argument: .entity(.audioOutputDevice), allowsBackgroundExecution: false)
        let registry = [inspect, arrange, center, cleanup, shareLink, adminToggle, audioVolume, awakeStart, audioOutput]
            .reduce(into: [String: AIActionDescriptor]()) { $0[$1.id] = $1 }

        var readyAvailability: AIAvailabilitySnapshot = Dictionary(
            uniqueKeysWithValues: [inspect, arrange, center, cleanup, shareLink, adminToggle, audioVolume, awakeStart]
                .map { ($0.id, AIActionAvailability.ready) })
        readyAvailability["audio.output.speakers"] = .ready
        readyAvailability["audio.output.headphones"] = .ready

        func step(_ id: String, _ argument: AIActionArgument = .none) -> AIPlanStep {
            AIPlanStep(actionID: id, argument: argument)
        }

        func plan(_ steps: [AIPlanStep], revision: Int = 1, background: Bool = false) -> AIActionPlan {
            AIActionPlan(revision: revision, steps: steps, allowsBackgroundExecution: background)
        }

        func outcome(_ plan: AIActionPlan, approvals: Set<AIApproval> = [],
                     availability: AIAvailabilitySnapshot = readyAvailability) -> AIPlanValidation {
            AIPlanValidator.validate(plan, registry: registry, availability: availability, approvals: approvals)
        }

        func violations(_ result: AIPlanValidation) -> [AIPlanViolation] {
            if case .rejected(let found) = result { return found }
            return []
        }

        func isValid(_ result: AIPlanValidation) -> Bool {
            if case .valid = result { return true }
            return false
        }

        func isNeedsApproval(_ result: AIPlanValidation) -> Bool {
            if case .needsApproval = result { return true }
            return false
        }

        func approvingPlan(_ plan: AIActionPlan) -> AIApproval {
            .plan(revision: plan.revision, steps: plan.steps)
        }

        func approvingEachStep(_ plan: AIActionPlan) -> Set<AIApproval> {
            Set(plan.steps.map { .step($0, revision: plan.revision) })
        }

        /// Every step approved individually, and the plan itself approved: a
        /// caller testing one rule (availability, duplicates, background)
        /// should never also be blocked on approval.
        func fullyApproved(_ plan: AIActionPlan) -> Set<AIApproval> {
            approvingEachStep(plan).union([approvingPlan(plan)])
        }

        /// A single-step plan, approved as its own reviewed plan, so a check
        /// exercising argument validation is never separately blocked on approval.
        func singleStepOutcome(_ s: AIPlanStep, availability: AIAvailabilitySnapshot = readyAvailability) -> AIPlanValidation {
            let p = plan([s])
            return outcome(p, approvals: [approvingPlan(p)], availability: availability)
        }

        // MARK: - Structure

        suite.expect(outcome(plan([])) == .rejected([.emptyPlan]),
                     "an agent cannot execute an empty plan")

        let invented = plan([step("model.invented.command")])
        suite.expect(outcome(invented, approvals: fullyApproved(invented))
                        == .rejected([.unknownAction("model.invented.command")]),
                     "a model cannot invent an executable action")

        suite.expect(isValid(outcome(plan([step("system.inspect")]))),
                     "read-only inspection remains available after context approval")

        // MARK: - Approval, graduated by risk

        let arrangeOnly = plan([step("windows.arrange")])
        suite.expect(outcome(arrangeOnly) == .needsApproval([
            AIApprovalRequest(step: step("windows.arrange"), risk: .reversible, scope: .plan),
        ]), "reversible steps wait for approval of the reviewed plan")

        suite.expect(isValid(outcome(arrangeOnly, approvals: [approvingPlan(arrangeOnly)])),
                     "approving the reviewed plan runs its reversible steps")

        suite.expect(isNeedsApproval(outcome(plan([step("windows.arrange")]))),
                     "a ready row proceeds to approval")

        let cleanupOnly = plan([step("cleaner.remove")])
        suite.expect(outcome(cleanupOnly, approvals: [approvingPlan(cleanupOnly)]) == .needsApproval([
            AIApprovalRequest(step: step("cleaner.remove"), risk: .destructive, scope: .step),
        ]), "a plan approval never satisfies a destructive step")

        let externalAndPrivileged = plan([step("share.link"), step("admin.toggle")])
        suite.expect(outcome(externalAndPrivileged, approvals: [approvingPlan(externalAndPrivileged)])
                        == .needsApproval([
                            AIApprovalRequest(step: step("share.link"), risk: .external, scope: .step),
                            AIApprovalRequest(step: step("admin.toggle"), risk: .privileged, scope: .step),
                        ]),
                     "external and privileged steps need their own approval")

        let highRisk = plan([step("cleaner.remove"), step("share.link"), step("admin.toggle")])
        suite.expect(isValid(outcome(highRisk, approvals: approvingEachStep(highRisk))),
                     "approving each step runs destructive, external and privileged steps")

        // MARK: - Availability, duplicate and background rules survive approval

        var noArrangeRow = readyAvailability
        noArrangeRow["windows.arrange"] = nil
        suite.expect(outcome(plan([step("windows.arrange")]), approvals: fullyApproved(plan([step("windows.arrange")])),
                             availability: noArrangeRow)
                        == .rejected([.notOffered(catalogID: "windows.arrange")]),
                     "a row the Command Bar is not offering cannot be planned")

        var arrangeNeedsSetup = readyAvailability
        arrangeNeedsSetup["windows.arrange"] = .needsSetup
        suite.expect(outcome(plan([step("windows.arrange")]), approvals: fullyApproved(plan([step("windows.arrange")])),
                             availability: arrangeNeedsSetup)
                        == .rejected([.needsSetup(catalogID: "windows.arrange")]),
                     "a feature that still needs setup cannot run from a plan")

        var cleanupNeedsPermission = readyAvailability
        cleanupNeedsPermission["cleaner.remove"] = .needsPermission
        suite.expect(outcome(plan([step("cleaner.remove")]), approvals: approvingEachStep(plan([step("cleaner.remove")])),
                             availability: cleanupNeedsPermission)
                        == .rejected([.needsPermission(catalogID: "cleaner.remove")]),
                     "an approval cannot substitute for a macOS permission")

        let duplicateInspect = plan([step("system.inspect"), step("system.inspect")])
        suite.expect(outcome(duplicateInspect, approvals: fullyApproved(duplicateInspect))
                        == .rejected([.duplicateStep(step("system.inspect"))]),
                     "duplicate actions are rejected instead of executed twice")

        let backgroundInspect = plan([step("system.inspect")], background: true)
        suite.expect(outcome(backgroundInspect, approvals: fullyApproved(backgroundInspect))
                        == .rejected([.backgroundExecutionDenied("system.inspect")]),
                     "a model cannot convert a foreground action into background work")

        // MARK: - Approval is bound to exact content, not a counter

        let approvedOriginal = plan([step("windows.arrange")], revision: 1)
        let editedSamePlan = plan([step("windows.arrange"), step("windows.center")], revision: 1)
        suite.expect(isNeedsApproval(outcome(editedSamePlan, approvals: [approvingPlan(approvedOriginal)])),
                     "changing a step after approval voids the plan approval")

        let revisionOne = plan([step("windows.arrange")], revision: 1)
        let revisionTwo = plan([step("windows.arrange")], revision: 2)
        suite.expect(isNeedsApproval(outcome(revisionTwo, approvals: [approvingPlan(revisionOne)])),
                     "a new plan revision voids earlier approvals")

        let cleanupRevisionOne = plan([step("cleaner.remove")], revision: 1)
        let cleanupRevisionTwo = plan([step("cleaner.remove")], revision: 2)
        suite.expect(isNeedsApproval(outcome(cleanupRevisionTwo, approvals: approvingEachStep(cleanupRevisionOne))),
                     "a step approval from an earlier revision does not carry over")

        // MARK: - Structural violations always win

        let mixedPlan = plan([step("model.invented.command"), step("windows.arrange")])
        suite.expect(outcome(mixedPlan, approvals: fullyApproved(mixedPlan))
                        == .rejected([.unknownAction("model.invented.command")]),
                     "approvals never override a structural violation")

        // MARK: - ValidatedPlan (task 01)

        let inspectOnly = plan([step("system.inspect")])
        if case .valid(let validated) = outcome(inspectOnly) {
            suite.expect(validated.plan == inspectOnly,
                         "a valid plan yields a ValidatedPlan carrying exactly the submitted plan")
        } else {
            suite.expect(false, "a valid plan yields a ValidatedPlan carrying exactly the submitted plan")
        }

        if case .valid = outcome(invented, approvals: fullyApproved(invented)) {
            suite.expect(false, "a rejected plan never yields a ValidatedPlan")
        } else {
            suite.expect(true, "a rejected plan never yields a ValidatedPlan")
        }

        let validatorPath = "Sources/PowerTools/Services/AI/AIPlanValidator.swift"
        let validatorCode = AIHarnessSource.code(at: validatorPath)
        suite.expect(!validatorCode.isEmpty, "the harness source checks can read AIPlanValidator.swift")

        let sourcesUnderTest = AIHarnessSource.swiftFiles(under: "Sources/PowerTools").filter { $0 != validatorPath }
        suite.expect(!sourcesUnderTest.isEmpty
                        && sourcesUnderTest.allSatisfy { !AIHarnessSource.code(at: $0).contains("ValidatedPlan(") },
                     "only AIPlanValidator constructs a ValidatedPlan")

        let allSources = AIHarnessSource.swiftFiles(under: "Sources/PowerTools")
        suite.expect(!allSources.isEmpty
                        && allSources.allSatisfy { path in
                            AIHarnessSource.code(at: path).split(separator: "\n").allSatisfy { line in
                                !(line.contains("ValidatedPlan") && (line.contains("Codable") || line.contains("Decodable")))
                            }
                        },
                     "a ValidatedPlan cannot be decoded into existence")

        // MARK: - Approval cannot be model output (task 02)

        let contractsPath = "Sources/PowerTools/Services/AI/AIHarnessContracts.swift"
        let contractsCode = AIHarnessSource.code(at: contractsPath)
        suite.expect(!contractsCode.isEmpty, "the harness source checks can read AIHarnessContracts.swift")

        let planStepBody = AIHarnessSource.body(of: "struct AIPlanStep", in: contractsCode).lowercased()
        suite.expect(!planStepBody.isEmpty && !planStepBody.contains("approv"),
                     "approval is never part of a model-produced step")

        // MARK: - Availability replaces feature/permission rules (task 03)

        let descriptorBody = AIHarnessSource.body(of: "struct AIActionDescriptor", in: contractsCode)
        suite.expect(!descriptorBody.isEmpty
                        && !descriptorBody.contains("AppFeature") && !descriptorBody.contains("AppPermission")
                        && !validatorCode.contains("AppFeature") && !validatorCode.contains("AppPermission"),
                     "availability comes from the snapshot, not from feature or permission rules")

        // MARK: - Typed arguments (task 04)

        suite.expect(singleStepOutcome(step("windows.arrange", .integer(5)))
                        == .rejected([.invalidArgument(actionID: "windows.arrange")]),
                     "an action without arguments rejects an argument")

        suite.expect(isValid(singleStepOutcome(step("audio.volume", .integer(30)))),
                     "a number inside the row's range is accepted")

        suite.expect(singleStepOutcome(step("audio.volume", .integer(101)))
                        == .rejected([.invalidArgument(actionID: "audio.volume")]),
                     "an out-of-range number is rejected")

        suite.expect(singleStepOutcome(step("audio.volume"))
                        == .rejected([.invalidArgument(actionID: "audio.volume")]),
                     "a required number cannot be left out")

        suite.expect(isValid(singleStepOutcome(step("awake.start"))),
                     "an optional number can be left out")

        suite.expect(singleStepOutcome(step("audio.volume", .entity(.audioOutputDevice, id: "speakers")))
                        == .rejected([.invalidArgument(actionID: "audio.volume")]),
                     "an argument of the wrong kind is rejected")

        suite.expect(singleStepOutcome(step("audio.output", .entity(.window, id: "speakers")))
                        == .rejected([.invalidArgument(actionID: "audio.output")]),
                     "an entity of the wrong kind is rejected")

        suite.expect(singleStepOutcome(step("audio.output", .entity(.audioOutputDevice, id: "")))
                        == .rejected([.invalidArgument(actionID: "audio.output")])
                        && singleStepOutcome(step("audio.output", .entity(.audioOutputDevice, id: "speakers\nheadphones")))
                        == .rejected([.invalidArgument(actionID: "audio.output")]),
                     "an empty or multi-line entity id is rejected")

        suite.expect(audioOutput.catalogID(for: .entity(.audioOutputDevice, id: "speakers")) == "audio.output.speakers",
                     "a target resolves to its Command Bar row id")

        suite.expect(singleStepOutcome(step("audio.output", .entity(.audioOutputDevice, id: "../../etc/passwd")))
                        == .rejected([.notOffered(catalogID: "audio.output.../../etc/passwd")]),
                     "a free-text target cannot become a row")

        let twoOutputs = plan([step("audio.output", .entity(.audioOutputDevice, id: "speakers")),
                               step("audio.output", .entity(.audioOutputDevice, id: "headphones"))])
        suite.expect(isValid(outcome(twoOutputs, approvals: [approvingPlan(twoOutputs)])),
                     "the same action on two different targets is allowed")

        let speakersStep = step("audio.output", .entity(.audioOutputDevice, id: "speakers"))
        let headphonesStep = step("audio.output", .entity(.audioOutputDevice, id: "headphones"))
        let headphonesPlan = plan([headphonesStep], revision: 1)
        suite.expect(isNeedsApproval(outcome(headphonesPlan, approvals: [.step(speakersStep, revision: 1)])),
                     "approving one target does not approve another")

        // MARK: - Production action registry (task 05)

        AIActionRegistryTests.run(suite)
    }
}

/// Reads Swift sources for contract checks. Whole-line comments are removed so
/// prose can neither satisfy nor break a check.
enum AIHarnessSource {
    static func code(at path: String) -> String {
        guard let text = try? String(contentsOfFile: path, encoding: .utf8) else { return "" }
        return text.split(separator: "\n", omittingEmptySubsequences: false)
            .filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//") }
            .joined(separator: "\n")
    }

    static func swiftFiles(under directory: String) -> [String] {
        let relative = FileManager.default.enumerator(atPath: directory)?.allObjects as? [String] ?? []
        return relative.filter { $0.hasSuffix(".swift") }.map { "\(directory)/\($0)" }.sorted()
    }

    /// The declaration starting at `marker`, up to the first line that is exactly "}".
    static func body(of marker: String, in code: String) -> String {
        guard let start = code.range(of: marker) else { return "" }
        let rest = code[start.lowerBound...]
        guard let end = rest.range(of: "\n}") else { return String(rest) }
        return String(rest[..<end.upperBound])
    }
}
