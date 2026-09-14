# Task 06 — Capability lease: allowed actions, step limit, deadline

| | |
| --- | --- |
| Depends on | Task 05 |
| Size | About 120 lines |
| Branch | `ai-harness/06-capability-lease` |
| Suite | `ai-harness` |

## Why

The registry says what AI may *ever* use. A single run should get much less:
only the actions relevant to the request, a small number of steps, and a
deadline. That is the capability lease.

Three reasons it matters here, all measured or decided earlier:

- **Smaller plans are better plans.** The on-device model picked wrong actions
  from a 74-action list (roadmap section 9). M4 retrieves a shortlist of at most
  10 actions per request; the lease is how that shortlist becomes enforceable,
  not just a prompt hint.
- **Plans must not grow.** A step limit keeps fan-out bounded (the roadmap budget
  allows at most 4 model calls per user action) and keeps the review sheet
  readable.
- **Stale approvals must expire.** A plan reviewed and then left open must not run
  an hour later against a Mac that has changed.

The lease is created by the app when a request starts. The plan has no lease
field, so a model cannot widen its own limits.

**Time is an input.** The validator takes `now` and never reads the clock. That
makes expiry exact, testable and deterministic.

**What does not belong here yet:** a limit on model turns needs an agent loop,
and receipts need an executor — both arrive in M4. The context manifest needs a
provider request — M2. Adding them now would be types nothing uses.

## Read first

- `Sources/PowerTools/Services/AI/AIHarnessContracts.swift`
- `Sources/PowerTools/Services/AI/AIPlanValidator.swift`
- `Tests/AIHarnessTests.swift`
- `docs/AI-PRODUCT-ROADMAP.md`, section 9 "What changes, and how often it
  becomes a problem"

## Change

### 1. `AIHarnessContracts.swift`

```swift
/// The limits of one run, set by the app when a request starts; a plan cannot widen them.
struct AICapabilityLease: Equatable {
    /// Registry action ids this run may use.
    let allowedActionIDs: Set<String>
    let maxSteps: Int
    let expiresAt: Date
}
```

Add to `AIPlanViolation`:

```swift
    case leaseExpired
    case tooManySteps(limit: Int)
    case outsideLease(actionID: String)
```

### 2. `AIPlanValidator.swift`

The signature becomes:

```swift
static func validate(_ plan: AIActionPlan,
                     registry: [String: AIActionDescriptor],
                     availability: AIAvailabilitySnapshot,
                     approvals: Set<AIApproval>,
                     lease: AICapabilityLease,
                     now: Date) -> AIPlanValidation
```

Right after the empty-plan guard and `var violations`:

```swift
if now >= lease.expiresAt { violations.append(.leaseExpired) }
if plan.steps.count > lease.maxSteps { violations.append(.tooManySteps(limit: lease.maxSteps)) }
```

In the loop, right after the registry lookup and before argument resolution:

```swift
guard lease.allowedActionIDs.contains(action.id) else {
    violations.append(.outsideLease(actionID: action.id))
    continue
}
```

The loop order is now: duplicate → unknown action → lease → argument →
availability → background → approval. Keep the three lines above exactly; the
mutation entries target the first and the `guard`.

### 3. `Tests/AIHarnessTests.swift`

**Fixtures.** Add a fixed clock and a default lease:

```swift
let fixedNow = Date(timeIntervalSinceReferenceDate: 800_000_000)
let openLease = AICapabilityLease(allowedActionIDs: Set(registry.keys), maxSteps: 10,
                                  expiresAt: fixedNow.addingTimeInterval(60))
```

Give `outcome` `lease: AICapabilityLease = openLease` and `now: Date = fixedNow`
parameters, and pass them through.

**Checks.** For each, use a plan that would otherwise be `.valid` (ready rows,
all approvals), so only the lease rule is tested.

| Message | Setup | Expect |
| --- | --- | --- |
| `a lease stops at its deadline` | `now` equal to `expiresAt` | `.rejected` containing `.leaseExpired` |
| `a lease is usable until its deadline` | `now` one second before `expiresAt` | `.valid` |
| `a plan cannot run more steps than its lease allows` | `maxSteps: 1`, two different steps | `.rejected` containing `.tooManySteps(limit: 1)` |
| `a registered, approved action outside the lease is rejected` | lease without `windows.arrange`; plan with `windows.arrange` | `.rejected([.outsideLease(actionID: "windows.arrange")])` |
| `a plan carries no limits of its own` | `AIHarnessSource.body(of: "struct AIActionPlan", …)`, lowercased | contains none of `lease`, `expire`, `deadline`, `maxsteps` |
| `the validator never reads the clock itself` | all of `AIPlanValidator.swift` | contains neither `Date()` nor `Date.now` |

### 4. `Tests/mutation_checks.py`

```python
    ("expired lease still runs", "ai-harness", "Sources/PowerTools/Services/AI/AIPlanValidator.swift",
     "if now >= lease.expiresAt { violations.append(.leaseExpired) }",
     "if now > lease.expiresAt.addingTimeInterval(3600) { violations.append(.leaseExpired) }",
     "a lease stops at its deadline"),
    ("lease ignored for registered actions", "ai-harness", "Sources/PowerTools/Services/AI/AIPlanValidator.swift",
     "guard lease.allowedActionIDs.contains(action.id) else {",
     "guard true else {",
     "a registered, approved action outside the lease is rejected"),
```

The second mutation compiles with a "will never be executed" warning; the check
must still fail.

## Done when

- `./build.sh --test-suite=ai-harness`, `./build.sh --test` and `./build.sh` pass.
- `python3 Tests/mutation_checks.py` passes with all ten harness mutations.

## Out of scope

Choosing a lease's actions from a shortlist, the model-turn limit and run
receipts (M4). The context manifest (M2).
