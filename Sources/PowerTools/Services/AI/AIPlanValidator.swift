// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint
// Copyright (C) 2026 PowerTools contributors

import Foundation

/// A plan that passed `AIPlanValidator`. Only the validator can create one, so
/// an executor that accepts `ValidatedPlan` cannot be handed an unchecked plan.
struct ValidatedPlan: Equatable {
    let plan: AIActionPlan

    fileprivate init(plan: AIActionPlan) {
        self.plan = plan
    }
}

enum AIPlanValidation: Equatable {
    case valid(ValidatedPlan)
    case rejected([AIPlanViolation])
}

/// A local gate between model output and action executors. Its input is already
/// parsed/structured model output; it never interprets model prose as a command.
enum AIPlanValidator {
    static func validate(_ plan: AIActionPlan,
                         registry: [String: AIActionDescriptor],
                         installedFeatures: Set<AppFeature>,
                         grantedPermissions: Set<AppPermission>) -> AIPlanValidation {
        guard !plan.steps.isEmpty else { return .rejected([.emptyPlan]) }

        var violations: [AIPlanViolation] = []
        var actionIDs = Set<String>()
        for step in plan.steps {
            guard actionIDs.insert(step.actionID).inserted else {
                violations.append(.duplicateAction(step.actionID))
                continue
            }
            guard let action = registry[step.actionID] else {
                violations.append(.unknownAction(step.actionID))
                continue
            }
            for feature in action.requiredFeatures where !installedFeatures.contains(feature) {
                violations.append(.unavailableFeature(actionID: action.id, feature: feature))
            }
            for permission in action.requiredPermissions where !grantedPermissions.contains(permission) {
                violations.append(.missingPermission(actionID: action.id, permission: permission))
            }
            if action.risk != .readOnly && !step.isExplicitlyApproved {
                violations.append(.approvalRequired(action.id))
            }
            if plan.allowsBackgroundExecution && !action.allowsBackgroundExecution {
                violations.append(.backgroundExecutionDenied(action.id))
            }
        }
        return violations.isEmpty ? .valid(ValidatedPlan(plan: plan)) : .rejected(violations)
    }
}
