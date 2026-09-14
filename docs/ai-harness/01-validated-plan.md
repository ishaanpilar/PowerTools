# Task 01 — `ValidatedPlan`: the validator is the only way to a runnable plan

| | |
| --- | --- |
| Depends on | Nothing |
| Size | About 120 lines |
| Branch | `ai-harness/01-validated-plan` |
| Suite | `ai-harness` |

## Why

`AIPlanValidator.validate` returns `[AIPlanViolation]`. Nothing forces a caller
to check that the list is empty, so a future executor could run a rejected plan
by forgetting one `if`. This task makes the validator return an outcome type,
and introduces `ValidatedPlan`, which only the validator can construct. From M4
on, executors accept only `ValidatedPlan`, so an unchecked plan cannot reach
them — the compiler refuses.

No behaviour changes: every existing check keeps its meaning.

## Read first

- `Sources/PowerTools/Services/AI/AIHarnessContracts.swift` — all of it
- `Tests/AIHarnessTests.swift` — all of it
- `build.sh` — the `TEST_SOURCES` list around
  `Sources/PowerTools/Services/AI/AIHarnessContracts.swift`
- `Tests/mutation_checks.py` — the `MUTATIONS` list format
- `Tests/TestSuite.swift` — `expect(_:_:)`

## Change

### 1. Create `Sources/PowerTools/Services/AI/AIPlanValidator.swift`

Move `AIPlanValidator` out of `AIHarnessContracts.swift` into this new file, and
copy that file's three header lines unchanged (moved code keeps its notices).
The file then contains exactly:

```swift
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
        // … the existing loop, unchanged …
        return violations.isEmpty ? .valid(ValidatedPlan(plan: plan)) : .rejected(violations)
    }
}
```

Rules:

- The initialiser is `fileprivate`, not `private`: `AIPlanValidator` is a
  different type in the same file and must be able to call it.
- `ValidatedPlan` must never conform to `Codable` or `Decodable`, and no
  extension may add another initialiser. A synthesised decoder would create one
  without validation.
- The `guard` line must be exactly as written above; the mutation entry below
  targets it.

### 2. Edit `AIHarnessContracts.swift`

Delete the `AIPlanValidator` enum and its doc comment. Nothing else changes.

### 3. Edit `build.sh`

In the test source list, add the new file on the line right after the existing
one:

```text
        Sources/PowerTools/Services/AI/AIHarnessContracts.swift
        Sources/PowerTools/Services/AI/AIPlanValidator.swift
```

### 4. Edit `Tests/AIHarnessTests.swift`

**a. Add a source helper** at the bottom of the file. Later tasks reuse it.

```swift
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
```

Tests run with the repository root as the working directory (existing checks
read `Resources/Info.plist` the same way).

**b. Replace the `validate` helper** so existing checks keep reading violations,
and add an `outcome` helper:

```swift
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
```

The nine existing `suite.expect` lines stay exactly as they are.

**c. Add these checks** after the existing ones.

| Message | Setup | Expect |
| --- | --- | --- |
| `a valid plan yields a ValidatedPlan carrying exactly the submitted plan` | One approved `system.inspect` step | `.valid(v)` where `v.plan` equals the submitted `AIActionPlan` |
| `a rejected plan never yields a ValidatedPlan` | `model.invented.command`, approved | outcome is `.rejected`, not `.valid` |
| `the harness source checks can read AIPlanValidator.swift` | `AIHarnessSource.code(at:)` on the validator file | non-empty |
| `only AIPlanValidator constructs a ValidatedPlan` | Every file from `swiftFiles(under: "Sources/PowerTools")` except the validator file | none contains `ValidatedPlan(` |
| `a ValidatedPlan cannot be decoded into existence` | Every Swift file under `Sources/PowerTools` | no line contains both `ValidatedPlan` and `Codable` or `Decodable` |

For the first check, write it so a non-`.valid` outcome fails with the same
message:

```swift
let inspectOnly = [AIPlanStep(actionID: "system.inspect", isExplicitlyApproved: true)]
if case .valid(let validated) = outcome(inspectOnly) {
    suite.expect(validated.plan == AIActionPlan(steps: inspectOnly, allowsBackgroundExecution: false),
                 "a valid plan yields a ValidatedPlan carrying exactly the submitted plan")
} else {
    suite.expect(false, "a valid plan yields a ValidatedPlan carrying exactly the submitted plan")
}
```

### 5. Add a mutation entry to `Tests/mutation_checks.py`

Append to `MUTATIONS`:

```python
    ("empty plan becomes runnable", "ai-harness", "Sources/PowerTools/Services/AI/AIPlanValidator.swift",
     "guard !plan.steps.isEmpty else { return .rejected([.emptyPlan]) }",
     "guard !plan.steps.isEmpty else { return .valid(ValidatedPlan(plan: plan)) }",
     "an agent cannot execute an empty plan"),
```

## Done when

- `./build.sh --test-suite=ai-harness` passes, with 14 checks.
- `./build.sh --test` prints `TESTS OK`.
- `./build.sh` succeeds with no new warnings.
- `python3 Tests/mutation_checks.py` passes, after `git add` of the new file.
- Removing `fileprivate` and constructing `ValidatedPlan(plan:)` anywhere else
  makes `only AIPlanValidator constructs a ValidatedPlan` fail. Try it once, then
  undo it.

## Out of scope

Approvals, availability, arguments, the registry and the lease: tasks 02–06.
Do not rename `isExplicitlyApproved` yet; task 02 removes it.
