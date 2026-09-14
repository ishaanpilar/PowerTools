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

        func validate(_ steps: [AIPlanStep], background: Bool = false,
                      features: Set<AppFeature> = [.monitorCPU, .windowLayout, .cleaner],
                      permissions: Set<AppPermission> = [.accessibility, .fullDiskAccess]) -> [AIPlanViolation] {
            AIPlanValidator.validate(
                AIActionPlan(steps: steps, allowsBackgroundExecution: background),
                registry: registry,
                installedFeatures: features,
                grantedPermissions: permissions
            )
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
    }
}
