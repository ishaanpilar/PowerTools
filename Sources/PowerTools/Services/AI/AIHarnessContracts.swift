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

/// A target the Command Bar builds one row for; the row id is "<action id>.<entity id>".
enum AIEntityKind: String, CaseIterable, Hashable {
    case application
    case window
    case windowLayout
    case audioOutputDevice
    case featureToggle
    case configuredFolder
}

enum AIArgumentKind: Equatable {
    case none
    case integer(ClosedRange<Int>, optional: Bool)
    case entity(AIEntityKind)
}

enum AIActionArgument: Hashable {
    case none
    case integer(Int)
    case entity(AIEntityKind, id: String)
}

/// A deterministic operation the app is prepared to offer to an AI planner.
/// The executor is intentionally kept outside this pure contract so planning
/// and approval can be tested without touching the Mac.
struct AIActionDescriptor: Equatable {
    /// A Command Bar row id; for an entity argument, the prefix before the target.
    let id: String
    let risk: AIActionRisk
    let argument: AIArgumentKind
    let allowsBackgroundExecution: Bool

    /// The Command Bar row this argument would run, or nil when the argument does not fit.
    func catalogID(for value: AIActionArgument) -> String? {
        switch (argument, value) {
        case (.none, .none):
            return id
        case (.integer(_, let optional), .none):
            return optional ? id : nil
        case (.integer(let range, _), .integer(let number)):
            return range.contains(number) ? id : nil
        case (.entity(let kind), .entity(let valueKind, let entityID)):
            guard valueKind == kind, !entityID.isEmpty,
                  !entityID.contains(where: \.isNewline) else { return nil }
            return "\(id).\(entityID)"
        default:
            return nil
        }
    }
}

/// One step a model proposed. It can name an action and its argument, never approve it.
struct AIPlanStep: Hashable {
    let actionID: String
    let argument: AIActionArgument
}

/// `revision` is assigned by the app, and changes whenever the plan's content does.
struct AIActionPlan: Equatable {
    let revision: Int
    let steps: [AIPlanStep]
    let allowsBackgroundExecution: Bool
}

/// Created only by the plan review interface, never parsed from model output.
enum AIApproval: Hashable {
    /// Covers the reversible steps of exactly these steps at this revision.
    case plan(revision: Int, steps: [AIPlanStep])
    /// Covers one step at this revision; required above reversible.
    case step(AIPlanStep, revision: Int)
}

enum AIApprovalScope: Equatable {
    case plan
    case step
}

/// What the review sheet must ask the person for before a plan can run.
struct AIApprovalRequest: Equatable {
    let step: AIPlanStep
    let risk: AIActionRisk
    let scope: AIApprovalScope
}

/// The Command Bar's own answer for a row, read from `CommandBarEntry.trouble`.
enum AIActionAvailability: Equatable {
    case ready
    case needsSetup
    case needsPermission
}

/// Keyed by Command Bar row id. A missing key means the bar is not offering that row now.
typealias AIAvailabilitySnapshot = [String: AIActionAvailability]

enum AIPlanViolation: Equatable {
    case emptyPlan
    case duplicateStep(AIPlanStep)
    case unknownAction(String)
    case invalidArgument(actionID: String)
    case notOffered(catalogID: String)
    case needsSetup(catalogID: String)
    case needsPermission(catalogID: String)
    case backgroundExecutionDenied(String)
}
