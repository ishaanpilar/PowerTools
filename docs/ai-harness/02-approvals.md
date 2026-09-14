# Task 02 — Approvals come from the app, bound to the exact plan, graduated by risk

| | |
| --- | --- |
| Depends on | Task 01 |
| Size | About 180 lines |
| Branch | `ai-harness/02-approvals` |
| Suite | `ai-harness` |

## Why

Three problems, one change.

1. **A model can approve itself.** `AIPlanStep` carries `isExplicitlyApproved`.
   Plan steps are exactly what a model produces, so nothing stops a model from
   emitting `isExplicitlyApproved: true`. Approval must be a separate input that
   only the plan review interface creates (M4). The step type must not be able to
   express approval at all.
2. **Approval is not tied to what was approved.** A boolean survives any edit to
   the plan. If a person approves "set volume to 30" and the plan later says
   "set volume to 100", the approval must not carry over. A step approval
   records the exact step and plan revision. A plan approval records the exact
   list of steps — not only the revision, because whoever builds the plan could
   change a step without changing the number.
3. **One flag covers five risk levels.** The validator only separates
   `readOnly` from everything else. The intended rule, now enforced:

   | Risk | Needs |
   | --- | --- |
   | `readOnly` | Nothing |
   | `reversible` | Approval of the reviewed plan, or of the step |
   | `destructive`, `external`, `privileged` | Approval of that exact step; a plan approval never counts |

   This uses `AIActionRisk`'s existing `Comparable` conformance, which nothing
   used until now.

Missing approvals are not errors in the plan: they are the normal state before
the person has reviewed it. So the validator gets a third outcome,
`.needsApproval`, which lists what the review sheet must ask for. Structural
problems always win: a plan with an unknown action is rejected even if every
approval is present.

## Read first

- `docs/ai-harness/01-validated-plan.md` (done) and its result
- `Sources/PowerTools/Services/AI/AIHarnessContracts.swift`
- `Sources/PowerTools/Services/AI/AIPlanValidator.swift`
- `Tests/AIHarnessTests.swift`

## Change

### 1. `AIHarnessContracts.swift`

Replace `AIPlanStep` and `AIActionPlan`, remove `approvalRequired` from
`AIPlanViolation`, and add the approval types:

```swift
/// One step a model proposed. It can name an action, never approve it.
struct AIPlanStep: Hashable {
    let actionID: String
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
```

`AIPlanViolation` keeps `emptyPlan`, `duplicateAction`, `unknownAction`,
`unavailableFeature`, `missingPermission` and `backgroundExecutionDenied`.

### 2. `AIPlanValidator.swift`

```swift
enum AIPlanValidation: Equatable {
    case valid(ValidatedPlan)
    case needsApproval([AIApprovalRequest])
    case rejected([AIPlanViolation])
}
```

Change the signature and the end of `validate`, and add the helper:

```swift
static func validate(_ plan: AIActionPlan,
                     registry: [String: AIActionDescriptor],
                     installedFeatures: Set<AppFeature>,
                     grantedPermissions: Set<AppPermission>,
                     approvals: Set<AIApproval>) -> AIPlanValidation {
    guard !plan.steps.isEmpty else { return .rejected([.emptyPlan]) }

    var violations: [AIPlanViolation] = []
    var pending: [AIApprovalRequest] = []
    // … existing loop; replace its `isExplicitlyApproved` check with:
    //     if let request = approvalRequest(for: step, risk: action.risk, in: plan, approvals: approvals) {
    //         pending.append(request)
    //     }

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
```

Keep the two `let needsStepApproval` and `if !needsStepApproval` lines exactly as
written; the mutation entries target them. Requests keep the order of the plan's
steps.

### 3. `Tests/AIHarnessTests.swift`

**Fixtures.** Extend the registry to one action per risk level. Actions without
requirements use empty sets:

| id | Risk | Features | Permissions |
| --- | --- | --- | --- |
| `system.inspect` | `readOnly` | `.monitorCPU` | — |
| `windows.arrange` | `reversible` | `.windowLayout` | `.accessibility` |
| `windows.center` | `reversible` | `.windowLayout` | `.accessibility` |
| `cleaner.remove` | `destructive` | `.cleaner` | `.fullDiskAccess` |
| `share.link` | `external` | — | — |
| `admin.toggle` | `privileged` | — | — |

**Helpers.** Replace the step-based helpers with plan-based ones:

```swift
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

func approvingPlan(_ plan: AIActionPlan) -> AIApproval {
    .plan(revision: plan.revision, steps: plan.steps)
}

func approvingEachStep(_ plan: AIActionPlan) -> Set<AIApproval> {
    Set(plan.steps.map { .step($0, revision: plan.revision) })
}
```

**Keep these checks**, passing every approval so only their own rule is under
test: `an agent cannot execute an empty plan`,
`a model cannot invent an executable action`,
`an installed-feature boundary cannot be bypassed by approval`,
`an approval cannot substitute for a macOS permission`,
`duplicate actions are rejected instead of executed twice`,
`a model cannot convert a foreground action into background work`, and the
task 01 checks (adapt their plans to `plan(_:)`).

**Remove** `reversible actions require final-plan approval` and
`destructive actions require target-specific approval`; the checks below replace
them.

**Add:**

| Message | Setup | Expect |
| --- | --- | --- |
| `read-only inspection remains available after context approval` | `plan(["system.inspect"])`, no approvals | `.valid` |
| `reversible steps wait for approval of the reviewed plan` | `plan(["windows.arrange"])`, no approvals | `.needsApproval([AIApprovalRequest(step: arrange, risk: .reversible, scope: .plan)])` |
| `approving the reviewed plan runs its reversible steps` | same plan, `approvingPlan` | `.valid` |
| `a plan approval never satisfies a destructive step` | `plan(["cleaner.remove"])`, `approvingPlan` | `.needsApproval` with one `.step` request |
| `external and privileged steps need their own approval` | `plan(["share.link", "admin.toggle"])`, `approvingPlan` | `.needsApproval` with two `.step` requests, in step order |
| `approving each step runs destructive, external and privileged steps` | `plan(["cleaner.remove", "share.link", "admin.toggle"])`, `approvingEachStep` | `.valid` |
| `changing a step after approval voids the plan approval` | approve `plan(["windows.arrange"])`; validate `plan(["windows.arrange", "windows.center"])`, same revision | `.needsApproval` |
| `a new plan revision voids earlier approvals` | approve `plan(["windows.arrange"], revision: 1)`; validate the same steps at revision 2 | `.needsApproval` |
| `a step approval from an earlier revision does not carry over` | `approvingEachStep` of `plan(["cleaner.remove"], revision: 1)`; validate at revision 2 | `.needsApproval` |
| `approvals never override a structural violation` | `plan(["model.invented.command", "windows.arrange"])` with both approval kinds | `.rejected([.unknownAction("model.invented.command")])` |
| `the harness source checks can read AIHarnessContracts.swift` | `AIHarnessSource.code(at:)` on the contracts file | non-empty |
| `approval is never part of a model-produced step` | `AIHarnessSource.body(of: "struct AIPlanStep", in:)`, lowercased | does not contain `approv` |

### 4. `Tests/mutation_checks.py`

```python
    ("plan approval covers destructive steps", "ai-harness", "Sources/PowerTools/Services/AI/AIPlanValidator.swift",
     "let needsStepApproval = risk > .reversible",
     "let needsStepApproval = risk > .destructive",
     "a plan approval never satisfies a destructive step"),
    ("plan approval ignores its steps", "ai-harness", "Sources/PowerTools/Services/AI/AIPlanValidator.swift",
     "if !needsStepApproval && approvals.contains(.plan(revision: plan.revision, steps: plan.steps)) { return nil }",
     "if !needsStepApproval && approvals.contains(where: { if case .plan(let revision, _) = $0 { return revision == plan.revision }; return false }) { return nil }",
     "changing a step after approval voids the plan approval"),
```

## Done when

- `./build.sh --test-suite=ai-harness`, `./build.sh --test` and `./build.sh` pass.
- `python3 Tests/mutation_checks.py` passes with all three harness mutations.
- `grep -rn isExplicitlyApproved Sources Tests` finds nothing.

## Out of scope

Replacing features and permissions with live availability (task 03). The
review sheet that creates `AIApproval` values (M4); when it exists, M4 adds a
check that nothing else constructs them.
