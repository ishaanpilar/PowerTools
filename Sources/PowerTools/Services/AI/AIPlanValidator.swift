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
    case needsApproval([AIApprovalRequest])
    case rejected([AIPlanViolation])
}

/// A local gate between model output and action executors. Its input is already
/// parsed/structured model output; it never interprets model prose as a command.
enum AIPlanValidator {
    static func validate(_ plan: AIActionPlan,
                         registry: [String: AIActionDescriptor],
                         installedFeatures: Set<AppFeature>,
                         grantedPermissions: Set<AppPermission>,
                         approvals: Set<AIApproval>) -> AIPlanValidation {
        guard !plan.steps.isEmpty else { return .rejected([.emptyPlan]) }

        var violations: [AIPlanViolation] = []
        var pending: [AIApprovalRequest] = []
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
            if let request = approvalRequest(for: step, risk: action.risk, in: plan, approvals: approvals) {
                pending.append(request)
            }
            if plan.allowsBackgroundExecution && !action.allowsBackgroundExecution {
                violations.append(.backgroundExecutionDenied(action.id))
            }
        }

        if !violations.isEmpty { return .rejected(violations) }
        if !pending.isEmpty { return .needsApproval(pending) }
        return .valid(ValidatedPlan(plan: plan))
    }

    private static func approvalRequest(for step: AIPlanStep,
                                        risk: AIActionRisk,
                                        in plan: AIActionPlan,
                                        approvals: Set<AIApproval>) -> AIApprovalRequest? {
        guard risk > .readOnly else { return nil }
        let needsStepApproval = risk > .reversible
        if approvals.contains(.step(step, revision: plan.revision)) { return nil }
        if !needsStepApproval && approvals.contains(.plan(revision: plan.revision, steps: plan.steps)) { return nil }
        return AIApprovalRequest(step: step, risk: risk, scope: needsStepApproval ? .step : .plan)
    }
}
