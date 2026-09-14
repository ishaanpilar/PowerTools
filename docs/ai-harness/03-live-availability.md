# Task 03 — Availability comes from live Command Bar rows, not a second copy of rules

| | |
| --- | --- |
| Depends on | Task 02 |
| Size | About 110 lines |
| Branch | `ai-harness/03-live-availability` |
| Suite | `ai-harness` |

## Why

`AIActionDescriptor` declares `requiredFeatures` and `requiredPermissions`. The
Command Bar already answers the same question at runtime: `CommandBarCatalog`
builds a row only when its feature is installed, and marks it with
`CommandBarEntry.trouble` when it still needs setup (`.needsSetup`) or a macOS
permission (`.needsPermission`). Two independent answers to one question drift
apart, and nothing would force them to agree.

So descriptors stop carrying requirements. The validator instead receives a
**snapshot of the live answer**, keyed by Command Bar row id:

| Snapshot value | Meaning | Validator |
| --- | --- | --- |
| key missing | The bar is not offering that row now (feature not installed, or row not built) | Reject: `notOffered` |
| `.needsSetup` | `trouble == .needsSetup` | Reject: `needsSetup` |
| `.needsPermission` | `trouble == .needsPermission` | Reject: `needsPermission` |
| `.ready` | `trouble == nil` | Continue to approval |

**One difference is deliberate and must survive:** when you press Return on a row
that needs a permission, the Command Bar runs it anyway, because running it is
what makes macOS show the permission prompt. A plan must never do that — a
plan's side effects are only the approved actions, and a permission prompt
appearing mid-plan is neither. So the validator rejects `.needsPermission` even
when every approval is present. Leave a one-line comment at that case so nobody
"aligns" the two.

The snapshot is built from `CommandBarCatalog.build(…)` in M4, in app code that
the test build does not compile. M1 needs only the type and the rule.

## Read first

- `Sources/PowerTools/Services/CommandBar/CommandBarCatalog.swift`, lines 1–110
  (`CommandBarEntry`, `Trouble`, `needsPrompt`) — read only, do not change
- `Sources/PowerTools/Services/AI/AIHarnessContracts.swift`
- `Sources/PowerTools/Services/AI/AIPlanValidator.swift`
- `Tests/AIHarnessTests.swift`

## Change

### 1. `AIHarnessContracts.swift`

```swift
struct AIActionDescriptor: Equatable {
    let id: String
    let risk: AIActionRisk
    let allowsBackgroundExecution: Bool
}

/// The Command Bar's own answer for a row, read from `CommandBarEntry.trouble`.
enum AIActionAvailability: Equatable {
    case ready
    case needsSetup
    case needsPermission
}

/// Keyed by Command Bar row id. A missing key means the bar is not offering that row now.
typealias AIAvailabilitySnapshot = [String: AIActionAvailability]
```

In `AIPlanViolation`, replace `unavailableFeature(actionID:feature:)` and
`missingPermission(actionID:permission:)` with:

```swift
    case notOffered(catalogID: String)
    case needsSetup(catalogID: String)
    case needsPermission(catalogID: String)
```

### 2. `AIPlanValidator.swift`

Replace the `installedFeatures` and `grantedPermissions` parameters with
`availability: AIAvailabilitySnapshot`. The signature becomes:

```swift
static func validate(_ plan: AIActionPlan,
                     registry: [String: AIActionDescriptor],
                     availability: AIAvailabilitySnapshot,
                     approvals: Set<AIApproval>) -> AIPlanValidation
```

Replace the feature and permission loops with this block, placed right after the
registry lookup. Keep the case order and the `case .ready?:` line exactly; the
mutation entry targets it. `catalogID` is a local so that task 04 only changes
how it is computed.

```swift
let catalogID = action.id
switch availability[catalogID] {
case .ready?:
    break
case .needsSetup?:
    violations.append(.needsSetup(catalogID: catalogID))
    continue
case .needsPermission?:
    // The Command Bar runs such a row to raise the macOS prompt; a plan never does.
    violations.append(.needsPermission(catalogID: catalogID))
    continue
case nil:
    violations.append(.notOffered(catalogID: catalogID))
    continue
}
```

A step that fails availability produces no approval request (the `continue`
skips it).

### 3. `Tests/AIHarnessTests.swift`

**Fixtures.** Drop `requiredFeatures` and `requiredPermissions` from every
fixture descriptor. Add a default snapshot marking every fixture id `.ready`, and
give `outcome` an `availability:` parameter defaulting to it, replacing
`features:` and `permissions:`.

**Replace** `an installed-feature boundary cannot be bypassed by approval` with
`a row the Command Bar is not offering cannot be planned`.

**Checks:**

| Message | Setup | Expect |
| --- | --- | --- |
| `a row the Command Bar is not offering cannot be planned` | `windows.arrange` missing from the snapshot; `approvingPlan` | `.rejected([.notOffered(catalogID: "windows.arrange")])` |
| `a feature that still needs setup cannot run from a plan` | `windows.arrange` is `.needsSetup`; `approvingPlan` | `.rejected([.needsSetup(catalogID: "windows.arrange")])` |
| `an approval cannot substitute for a macOS permission` *(existing message, new setup)* | `cleaner.remove` is `.needsPermission`; `approvingEachStep` | `.rejected([.needsPermission(catalogID: "cleaner.remove")])` |
| `a ready row proceeds to approval` | all `.ready`, `plan(["windows.arrange"])`, no approvals | `.needsApproval` |
| `the harness source checks can read AIPlanValidator.swift` *(existing)* | — | unchanged |
| `availability comes from the snapshot, not from feature or permission rules` | `AIHarnessSource.body(of: "struct AIActionDescriptor", …)` and all of `AIPlanValidator.swift` | neither contains `AppFeature` or `AppPermission` |

Every other existing check keeps its message and expectation.

### 4. `Tests/mutation_checks.py`

```python
    ("permission-blocked row treated as ready", "ai-harness", "Sources/PowerTools/Services/AI/AIPlanValidator.swift",
     "case .ready?:",
     "case .ready?, .needsPermission?:",
     "an approval cannot substitute for a macOS permission"),
```

The mutated file compiles with an "already handled" warning for the later case;
that is expected, and the check must still fail.

## Done when

- `./build.sh --test-suite=ai-harness`, `./build.sh --test` and `./build.sh` pass.
- `python3 Tests/mutation_checks.py` passes with all four harness mutations.
- `grep -n "AppFeature\|AppPermission" Sources/PowerTools/Services/AI/*.swift`
  finds nothing.

## Out of scope

Building the snapshot from `CommandBarCatalog` (M4). Arguments and entity row
ids (task 04).
