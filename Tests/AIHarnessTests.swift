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
        let cleanup = AIActionDescriptor(
            id: "cleaner.remove",
            risk: .destructive,
            requiredFeatures: [.cleaner],
            requiredPermissions: [.fullDiskAccess],
            allowsBackgroundExecution: false
        )
        let registry = [inspect, arrange, cleanup].reduce(into: [String: AIActionDescriptor]()) {
            $0[$1.id] = $1
        }

        func outcome(_ steps: [AIPlanStep], background: Bool = false,
                     features: Set<AppFeature> = [.monitorCPU, .windowLayout, .cleaner],
                     permissions: Set<AppPermission> = [.accessibility, .fullDiskAccess]) -> AIPlanValidation {
            AIPlanValidator.validate(
                AIActionPlan(steps: steps, allowsBackgroundExecution: background),
                registry: registry,
                installedFeatures: features,
                grantedPermissions: permissions
            )
        }

        func validate(_ steps: [AIPlanStep], background: Bool = false,
                      features: Set<AppFeature> = [.monitorCPU, .windowLayout, .cleaner],
                      permissions: Set<AppPermission> = [.accessibility, .fullDiskAccess]) -> [AIPlanViolation] {
            if case .rejected(let violations) = outcome(steps, background: background,
                                                        features: features, permissions: permissions) {
                return violations
            }
            return []
        }

        suite.expect(validate([]) == [.emptyPlan], "an agent cannot execute an empty plan")
        suite.expect(validate([AIPlanStep(actionID: "model.invented.command", isExplicitlyApproved: true)])
                        == [.unknownAction("model.invented.command")],
                     "a model cannot invent an executable action")
        suite.expect(validate([AIPlanStep(actionID: "system.inspect", isExplicitlyApproved: false)]).isEmpty,
                     "read-only inspection remains available after context approval")
        suite.expect(validate([AIPlanStep(actionID: "windows.arrange", isExplicitlyApproved: false)])
                        == [.approvalRequired("windows.arrange")],
                     "reversible actions require final-plan approval")
        suite.expect(validate([AIPlanStep(actionID: "cleaner.remove", isExplicitlyApproved: false)])
                        == [.approvalRequired("cleaner.remove")],
                     "destructive actions require target-specific approval")
        suite.expect(validate([AIPlanStep(actionID: "windows.arrange", isExplicitlyApproved: true)],
                              features: [.monitorCPU, .cleaner]).contains(
                                .unavailableFeature(actionID: "windows.arrange", feature: .windowLayout)),
                     "an installed-feature boundary cannot be bypassed by approval")
        suite.expect(validate([AIPlanStep(actionID: "cleaner.remove", isExplicitlyApproved: true)],
                              permissions: [.accessibility]).contains(
                                .missingPermission(actionID: "cleaner.remove", permission: .fullDiskAccess)),
                     "an approval cannot substitute for a macOS permission")
        suite.expect(validate([AIPlanStep(actionID: "system.inspect", isExplicitlyApproved: true),
                               AIPlanStep(actionID: "system.inspect", isExplicitlyApproved: true)])
                        == [.duplicateAction("system.inspect")],
                     "duplicate actions are rejected instead of executed twice")
        suite.expect(validate([AIPlanStep(actionID: "system.inspect", isExplicitlyApproved: true)],
                              background: true) == [.backgroundExecutionDenied("system.inspect")],
                     "a model cannot convert a foreground action into background work")

        let inspectOnly = [AIPlanStep(actionID: "system.inspect", isExplicitlyApproved: true)]
        if case .valid(let validated) = outcome(inspectOnly) {
            suite.expect(validated.plan == AIActionPlan(steps: inspectOnly, allowsBackgroundExecution: false),
                         "a valid plan yields a ValidatedPlan carrying exactly the submitted plan")
        } else {
            suite.expect(false, "a valid plan yields a ValidatedPlan carrying exactly the submitted plan")
        }

        let invented = [AIPlanStep(actionID: "model.invented.command", isExplicitlyApproved: true)]
        if case .valid = outcome(invented) {
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
