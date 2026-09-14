// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint
// Copyright (C) 2026 PowerTools contributors

import Foundation

/// The maximum consequence of a registered agent action. This value belongs to
/// the app, not to a model response, so changing a prompt cannot downgrade it.
enum AIActionRisk: String, CaseIterable, Comparable {
    case readOnly
    case reversible
    case destructive
    case external
    case privileged

    private var rank: Int {
        switch self {
        case .readOnly: return 0
        case .reversible: return 1
        case .destructive: return 2
        case .external: return 3
        case .privileged: return 4
        }
    }

    static func < (lhs: AIActionRisk, rhs: AIActionRisk) -> Bool {
        lhs.rank < rhs.rank
    }
}

/// A deterministic operation the app is prepared to offer to an AI planner.
/// The executor is intentionally kept outside this pure contract so planning
/// and approval can be tested without touching the Mac.
struct AIActionDescriptor: Equatable {
    let id: String
    let risk: AIActionRisk
    let requiredFeatures: Set<AppFeature>
    let requiredPermissions: Set<AppPermission>
    let allowsBackgroundExecution: Bool
}

struct AIPlanStep: Equatable {
    let actionID: String
    /// Approval is per final target/action, never inferred from a broad request.
    let isExplicitlyApproved: Bool
}

struct AIActionPlan: Equatable {
    let steps: [AIPlanStep]
    let allowsBackgroundExecution: Bool
}

enum AIPlanViolation: Equatable {
    case emptyPlan
    case duplicateAction(String)
    case unknownAction(String)
    case unavailableFeature(actionID: String, feature: AppFeature)
    case missingPermission(actionID: String, permission: AppPermission)
    case approvalRequired(String)
    case backgroundExecutionDenied(String)
}
