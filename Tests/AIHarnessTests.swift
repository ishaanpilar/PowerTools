// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint
// Copyright (C) 2026 PowerTools contributors

import Foundation

enum AIHarnessTests {
    static func run(_ suite: TestSuite) {
        let inspect = AIActionDescriptor(
            id: "system.inspect",
            risk: .readOnly,
            requiredFeatures: [.monitorCPU],
            requiredPermissions: [],
            allowsBackgroundExecution: false
        )
        let arrange = AIActionDescriptor(
            id: "windows.arrange",
            risk: .reversible,
            requiredFeatures: [.windowLayout],
            requiredPermissions: [.accessibility],
            allowsBackgroundExecution: false
        )
        let center = AIActionDescriptor(
            id: "windows.center",
            risk: .reversible,
            requiredFeatures: [.windowLayout],
            requiredPermissions: [.accessibility],
            allowsBackgroundExecution: false
        )
        let cleanup = AIActionDescriptor(
            id: "cleaner.remove",
            risk: .destructive,
            requiredFeatures: [.cleaner],
            requiredPermissions: [.fullDiskAccess],
            allowsBackgroundExecution: false
        )
        let shareLink = AIActionDescriptor(
            id: "share.link",
            risk: .external,
            requiredFeatures: [],
            requiredPermissions: [],
            allowsBackgroundExecution: false
        )
        let adminToggle = AIActionDescriptor(
            id: "admin.toggle",
            risk: .privileged,
            requiredFeatures: [],
            requiredPermissions: [],
            allowsBackgroundExecution: false
        )
        let registry = [inspect, arrange, center, cleanup, shareLink, adminToggle]
            .reduce(into: [String: AIActionDescriptor]()) { $0[$1.id] = $1 }

        func plan(_ ids: [String], revision: Int = 1, background: Bool = false) -> AIActionPlan {
            AIActionPlan(revision: revision, steps: ids.map { AIPlanStep(actionID: $0) },
                         allowsBackgroundExecution: background)
        }

        func outcome(_ plan: AIActionPlan, approvals: Set<AIApproval> = [],
                     features: Set<AppFeature> = [.monitorCPU, .windowLayout, .cleaner],
                     permissions: Set<AppPermission> = [.accessibility, .fullDiskAccess]) -> AIPlanValidation {
            AIPlanValidator.validate(plan, registry: registry, installedFeatures: features,
                                     grantedPermissions: permissions, approvals: approvals)
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
        /// caller testing one rule (features, permissions, duplicates,
        /// background) should never also be blocked on approval.
        func fullyApproved(_ plan: AIActionPlan) -> Set<AIApproval> {
            approvingEachStep(plan).union([approvingPlan(plan)])
        }

        // MARK: - Structure

        suite.expect(outcome(plan([])) == .rejected([.emptyPlan]),
                     "an agent cannot execute an empty plan")

        let invented = plan(["model.invented.command"])
        suite.expect(outcome(invented, approvals: fullyApproved(invented))
                        == .rejected([.unknownAction("model.invented.command")]),
                     "a model cannot invent an executable action")

        suite.expect(isValid(outcome(plan(["system.inspect"]))),
                     "read-only inspection remains available after context approval")

        // MARK: - Approval, graduated by risk

        let arrangeOnly = plan(["windows.arrange"])
        suite.expect(outcome(arrangeOnly) == .needsApproval([
            AIApprovalRequest(step: AIPlanStep(actionID: "windows.arrange"), risk: .reversible, scope: .plan),
        ]), "reversible steps wait for approval of the reviewed plan")

        suite.expect(isValid(outcome(arrangeOnly, approvals: [approvingPlan(arrangeOnly)])),
                     "approving the reviewed plan runs its reversible steps")

        let cleanupOnly = plan(["cleaner.remove"])
        suite.expect(outcome(cleanupOnly, approvals: [approvingPlan(cleanupOnly)]) == .needsApproval([
            AIApprovalRequest(step: AIPlanStep(actionID: "cleaner.remove"), risk: .destructive, scope: .step),
        ]), "a plan approval never satisfies a destructive step")

        let externalAndPrivileged = plan(["share.link", "admin.toggle"])
        suite.expect(outcome(externalAndPrivileged, approvals: [approvingPlan(externalAndPrivileged)])
                        == .needsApproval([
                            AIApprovalRequest(step: AIPlanStep(actionID: "share.link"), risk: .external, scope: .step),
                            AIApprovalRequest(step: AIPlanStep(actionID: "admin.toggle"), risk: .privileged, scope: .step),
                        ]),
                     "external and privileged steps need their own approval")

        let highRisk = plan(["cleaner.remove", "share.link", "admin.toggle"])
        suite.expect(isValid(outcome(highRisk, approvals: approvingEachStep(highRisk))),
                     "approving each step runs destructive, external and privileged steps")

        // MARK: - Feature, permission, duplicate and background rules survive approval

        let arrangeApproved = fullyApproved(plan(["windows.arrange"]))
        suite.expect(violations(outcome(plan(["windows.arrange"]), approvals: arrangeApproved,
                                        features: [.monitorCPU, .cleaner]))
                        .contains(.unavailableFeature(actionID: "windows.arrange", feature: .windowLayout)),
                     "an installed-feature boundary cannot be bypassed by approval")

        let cleanupApproved = fullyApproved(plan(["cleaner.remove"]))
        suite.expect(violations(outcome(plan(["cleaner.remove"]), approvals: cleanupApproved,
                                        permissions: [.accessibility]))
                        .contains(.missingPermission(actionID: "cleaner.remove", permission: .fullDiskAccess)),
                     "an approval cannot substitute for a macOS permission")

        let duplicateInspect = plan(["system.inspect", "system.inspect"])
        suite.expect(outcome(duplicateInspect, approvals: fullyApproved(duplicateInspect))
                        == .rejected([.duplicateAction("system.inspect")]),
                     "duplicate actions are rejected instead of executed twice")

        let backgroundInspect = plan(["system.inspect"], background: true)
        suite.expect(outcome(backgroundInspect, approvals: fullyApproved(backgroundInspect))
                        == .rejected([.backgroundExecutionDenied("system.inspect")]),
                     "a model cannot convert a foreground action into background work")

        // MARK: - Approval is bound to exact content, not a counter

        let approvedOriginal = plan(["windows.arrange"], revision: 1)
        let editedSamePlan = plan(["windows.arrange", "windows.center"], revision: 1)
        suite.expect(isNeedsApproval(outcome(editedSamePlan, approvals: [approvingPlan(approvedOriginal)])),
                     "changing a step after approval voids the plan approval")

        let revisionOne = plan(["windows.arrange"], revision: 1)
        let revisionTwo = plan(["windows.arrange"], revision: 2)
        suite.expect(isNeedsApproval(outcome(revisionTwo, approvals: [approvingPlan(revisionOne)])),
                     "a new plan revision voids earlier approvals")

        let cleanupRevisionOne = plan(["cleaner.remove"], revision: 1)
        let cleanupRevisionTwo = plan(["cleaner.remove"], revision: 2)
        suite.expect(isNeedsApproval(outcome(cleanupRevisionTwo, approvals: approvingEachStep(cleanupRevisionOne))),
                     "a step approval from an earlier revision does not carry over")

        // MARK: - Structural violations always win

        let mixedPlan = plan(["model.invented.command", "windows.arrange"])
        suite.expect(outcome(mixedPlan, approvals: fullyApproved(mixedPlan))
                        == .rejected([.unknownAction("model.invented.command")]),
                     "approvals never override a structural violation")

        // MARK: - ValidatedPlan (task 01)

        let inspectOnly = plan(["system.inspect"])
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
