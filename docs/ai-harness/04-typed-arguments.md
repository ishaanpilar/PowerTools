# Task 04 — Typed arguments that resolve to real Command Bar rows

| | |
| --- | --- |
| Depends on | Task 03 |
| Size | About 190 lines |
| Branch | `ai-harness/04-typed-arguments` |
| Suite | `ai-harness` |

## Why

A plan step today names an action and nothing else. Real steps need a target:
which window, which audio output, how many minutes, which folder. Targets are
exactly where injected content does damage — a clipboard item that says "open
`/etc`" must not become a step that opens `/etc`.

The Command Bar already has a safe shape for this, so we copy its shape rather
than invent one:

- **Numbers** are bounded by the row: `action.keepAwake` accepts `1...480`
  minutes and may be left out; `action.volume` requires `0...100`.
- **Targets are embedded in row ids.** The catalog builds one row per real
  target: `action.soundOutput.<device uid>`, `app.<id>`, `window.<id>`,
  `folder.<path>`, `toggle.<feature>`, `action.layout.<layout>`.

So an entity argument is valid only if the row `"<action id>.<entity id>"` is in
the live snapshot from task 03. A free-text path, an invented window or a
device that was unplugged simply does not resolve, and the plan is rejected as
`notOffered`. No new "entity snapshot" type is needed: the catalog rows *are*
the list of real targets.

This also fixes the duplicate rule. Rejecting a repeated action id is wrong once
targets exist — focusing window A and then window B is legitimate. Only an
identical step (same action, same argument) is rejected.

## Read first

- `Sources/PowerTools/Services/CommandBar/CommandBarCatalog.swift` — read only.
  Look at `action.keepAwake` (around line 450: `numericRange: 1...480`,
  `numericIsOptional: true`), `action.volume`, `action.soundOutput.\(…)`,
  `app.\(…)`, `window.\(…)` and `folder.\(…)`.
- `Sources/PowerTools/Services/AI/AIHarnessContracts.swift`
- `Sources/PowerTools/Services/AI/AIPlanValidator.swift`
- `Tests/AIHarnessTests.swift`

## Change

### 1. `AIHarnessContracts.swift`

Add:

```swift
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
```

Replace `AIActionDescriptor` and `AIPlanStep`:

```swift
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
```

Keep `return range.contains(number) ? id : nil` exactly; the mutation targets it.

In `AIPlanViolation`, replace `duplicateAction(String)` with
`duplicateStep(AIPlanStep)` and add `invalidArgument(actionID: String)`.

### 2. `AIPlanValidator.swift`

In the loop:

- Track `Set<AIPlanStep>` instead of `Set<String>`, appending
  `.duplicateStep(step)` for an identical repeat.
- After the registry lookup, replace `let catalogID = action.id` with:

```swift
guard let catalogID = action.catalogID(for: step.argument) else {
    violations.append(.invalidArgument(actionID: action.id))
    continue
}
```

The availability `switch` from task 03 stays exactly as it is, now looking up
the resolved row id.

### 3. `Tests/AIHarnessTests.swift`

**Fixtures.** Every existing fixture descriptor gets `argument: .none`. Add:

| id | Risk | Argument |
| --- | --- | --- |
| `audio.volume` | `reversible` | `.integer(0...100, optional: false)` |
| `awake.start` | `reversible` | `.integer(1...480, optional: true)` |
| `audio.output` | `reversible` | `.entity(.audioOutputDevice)` |

The default snapshot marks `.ready`: every argument-less fixture id,
`audio.volume`, `awake.start`, `audio.output.speakers` and
`audio.output.headphones`.

**Helpers.** Build plans from steps, and update every existing check to use them:

```swift
func step(_ id: String, _ argument: AIActionArgument = .none) -> AIPlanStep {
    AIPlanStep(actionID: id, argument: argument)
}

func plan(_ steps: [AIPlanStep], revision: Int = 1, background: Bool = false) -> AIActionPlan {
    AIActionPlan(revision: revision, steps: steps, allowsBackgroundExecution: background)
}
```

**Checks.** `duplicate actions are rejected instead of executed twice` keeps its
message and now expects `.rejected([.duplicateStep(step("system.inspect"))])`.
Add:

| Message | Setup (approvals: `approvingPlan` unless noted) | Expect |
| --- | --- | --- |
| `an action without arguments rejects an argument` | `step("windows.arrange", .integer(5))` | `.rejected([.invalidArgument(actionID: "windows.arrange")])` |
| `a number inside the row's range is accepted` | `step("audio.volume", .integer(30))` | `.valid` |
| `an out-of-range number is rejected` | `step("audio.volume", .integer(101))` | `.rejected([.invalidArgument(actionID: "audio.volume")])` |
| `a required number cannot be left out` | `step("audio.volume")` | `.rejected([.invalidArgument(actionID: "audio.volume")])` |
| `an optional number can be left out` | `step("awake.start")` | `.valid` |
| `an argument of the wrong kind is rejected` | `step("audio.volume", .entity(.audioOutputDevice, id: "speakers"))` | `.invalidArgument` |
| `an entity of the wrong kind is rejected` | `step("audio.output", .entity(.window, id: "speakers"))` | `.invalidArgument` |
| `an empty or multi-line entity id is rejected` | ids `""` and `"speakers\nheadphones"` | both `.invalidArgument` |
| `a target resolves to its Command Bar row id` | the `audio.output` descriptor's `catalogID(for: .entity(.audioOutputDevice, id: "speakers"))` | `"audio.output.speakers"` |
| `a free-text target cannot become a row` | `step("audio.output", .entity(.audioOutputDevice, id: "../../etc/passwd"))` | `.rejected([.notOffered(catalogID: "audio.output.../../etc/passwd")])` |
| `the same action on two different targets is allowed` | outputs `speakers` then `headphones` | `.valid` |
| `approving one target does not approve another` | approvals: only `.step(step("audio.output", .entity(.audioOutputDevice, id: "speakers")), revision: 1)`; plan: the `headphones` step at revision 1 | `.needsApproval` |

### 4. `Tests/mutation_checks.py`

```python
    ("number range ignored", "ai-harness", "Sources/PowerTools/Services/AI/AIHarnessContracts.swift",
     "return range.contains(number) ? id : nil",
     "return id",
     "an out-of-range number is rejected"),
```

## Done when

- `./build.sh --test-suite=ai-harness`, `./build.sh --test` and `./build.sh` pass.
- `python3 Tests/mutation_checks.py` passes with all five harness mutations.

## Out of scope

The production list of actions and its agreement with the catalog (task 05).
Choosing which window a layout applies to: `action.layout.<layout>` acts on the
frontmost window, and M4 decides how a plan focuses a window first.
