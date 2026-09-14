# AI harness implementation plan (milestone M1)

This folder turns milestone M1 of [the AI product roadmap](../AI-PRODUCT-ROADMAP.md)
into tasks a coding agent can build one at a time. Each task file is
self-contained: why it exists, what to read, the exact types, the checks to
add, how to prove the checks work, and when to stop.

**Goal of M1:** before any model output exists, make the plan contract
impossible to bypass. A model may *propose* a plan; only the app can decide
whether it runs. M1 is pure Swift: no model, no network, no interface, no
executor.

## Status

| Task | Title | Depends on | Status |
| --- | --- | --- | --- |
| [01](01-validated-plan.md) | `ValidatedPlan`: the validator is the only way to a runnable plan | — | Done — `59acc32`, `ai-harness/01-validated-plan`, 2026-09-14 |
| [02](02-approvals.md) | Approvals come from the app, bound to the exact plan, graduated by risk | 01 | Done — `4e0e1ab`, `ai-harness/02-approvals`, 2026-09-14 |
| [03](03-live-availability.md) | Availability comes from live Command Bar rows, not a second copy of rules | 02 | Done — `a03827a`, `ai-harness/03-live-availability`, 2026-09-14 |
| [04](04-typed-arguments.md) | Typed arguments that resolve to real Command Bar rows | 03 | Done — `291075c`, `ai-harness/04-typed-arguments`, 2026-09-14 |
| [05](05-action-registry.md) | The production action registry and its agreement with the catalog | 04 | Done — `d443a17`, `ai-harness/05-action-registry`, 2026-09-14 |
| [06](06-capability-lease.md) | Capability lease: allowed actions, step limit, deadline | 05 | Done — `68a8f06`, `ai-harness/06-capability-lease`, 2026-09-14 |
| [07](07-contract-docs.md) | `AI-HARNESS.md` names the check behind every guarantee | 06 | Done — `ai-harness/07-contract-docs`, 2026-09-14 (commit pending final verification) |

**M1 is complete as of 2026-09-14.** All seven tasks landed; the full suite
passes (32,791 checks) and `mutation_checks.py` proves all 18 guards, 11 of
them the AI harness's own. See [the roadmap](../AI-PRODUCT-ROADMAP.md), M1's
findings and section 3, for what closes and what remains for M2.

Work strictly in order. Update this table when a task is done: status, branch
and the date.

## How to work a task

1. **Start clean.** `git status` must show nothing of yours. Another session may
   share this checkout; never commit or revert files you did not change.
2. **Branch.** From an up-to-date `main`: `git switch -c ai-harness/NN-short-name`.
3. **Read** [AGENTS.md](../../AGENTS.md), this README, the task file, and every
   file under the task's *Read first*.
4. **Tests first.** Add or change the checks the task lists, then run
   `./build.sh --test-suite=ai-harness`. A compile error or failing check is the
   expected starting point.
5. **Implement** exactly the types and rules in the task. Where the task gives
   code, use it; where it gives a rule, write the smallest code that meets it.
6. **Verify, in this order:**
   ```sh
   ./build.sh --test-suite=ai-harness   # seconds
   ./build.sh --test                    # whole suite, must print TESTS OK
   ./build.sh                           # full app build, must finish without warnings you introduced
   ```
7. **Prove the guards.** Add the task's mutation entries to
   `Tests/mutation_checks.py`, then `git add` every new file (the tool copies
   only files git tracks) and run `python3 Tests/mutation_checks.py`. It must
   end without an error. It takes several minutes.
8. **Report** as `AGENTS.md` asks: what changed, every command run and its
   result, what you skipped and why. Update the status table.
9. **Commit only when the maintainer asks.** The maintainer reviews and merges
   every AI change.

### Stop and ask the maintainer when

- the task and the code disagree (a file moved, an identifier changed, a type
  already exists);
- a check cannot be written as the task describes;
- you need to change a file the task does not list;
- an unrelated test fails, before or after your change;
- the change grows past roughly 250 lines.

Do not work around any of these silently.

## Rules for every M1 task

- **Pure value types.** `struct` and `enum` only, `Equatable` or `Hashable`. No
  classes, singletons, `async`, networking, `UserDefaults` or UI.
- **No model code.** Do not import `FoundationModels`. Do not add providers,
  prompts, executors or views.
- **Do not touch `CommandBarCatalog.swift`** or any service. M1 reads the
  catalog's source in tests; it never changes it.
- **Swift 6.0.3 compatible.** CI builds with Xcode 16.2. Avoid
  `nonisolated(nonsending)`, `@concurrent`, `InlineArray`, raw identifiers and
  the `Synchronization` module.
- **Files.** Contract types live in
  `Sources/PowerTools/Services/AI/AIHarnessContracts.swift`, the validator in
  `Sources/PowerTools/Services/AI/AIPlanValidator.swift` (from task 01), the
  registry in `Sources/PowerTools/Services/AI/AIActionRegistry.swift` (task 05).
  Every new non-UI source must be added to the test list in `build.sh`.
- **Tests.** Validator checks live in `Tests/AIHarnessTests.swift`; registry
  checks in `Tests/AIActionRegistryTests.swift`, called from
  `AIHarnessTests.run`. Both run in the `ai-harness` suite. Check messages are
  unique sentences: the mutation tool and `AI-HARNESS.md` both find checks by
  their message.
- **Source-shape checks** first assert the file was read (a missing file must
  fail, not pass), strip whole-line comments, and pin only contract text such as
  type names and identifiers.
- **Headers.** A new file starts with the SPDX line and
  `// Copyright (C) 2026 PowerTools AI contributors`. Code moved from another
  file keeps that file's existing notices.
- **Comments are rare** and explain a non-obvious reason, never what the code
  does.

## The contract M1 ends with

```text
model output ── parsed by the app (M4) ──▶ AIActionPlan         revision assigned by the app
AIActionRegistry.byID ─────────────────────▶                     what AI may use, and its risk
live Command Bar rows ── snapshot ─────────▶                     what is offered right now
plan review interface ── AIApproval ───────▶  AIPlanValidator    what the person approved
AICapabilityLease + now ───────────────────▶   .validate(…)      the run's limits
                                                     │
                     ┌───────────────────────────────┼────────────────────────────┐
                 .rejected([AIPlanViolation])  .needsApproval([AIApprovalRequest])  .valid(ValidatedPlan)
                                                                                     │
                                                                  executor (M4) accepts only ValidatedPlan
```

The final shapes, for orientation. Each task gets there one step at a time;
follow the task file, not this sketch, while working.

```swift
enum AIActionRisk: String, CaseIterable, Comparable { case readOnly, reversible, destructive, external, privileged }
enum AIEntityKind: String, CaseIterable, Hashable { case application, window, windowLayout, audioOutputDevice, featureToggle, configuredFolder }
enum AIArgumentKind: Equatable { case none, integer(ClosedRange<Int>, optional: Bool), entity(AIEntityKind) }
enum AIActionArgument: Hashable { case none, integer(Int), entity(AIEntityKind, id: String) }

struct AIActionDescriptor: Equatable { let id: String; let risk: AIActionRisk; let argument: AIArgumentKind; let allowsBackgroundExecution: Bool }
struct AIPlanStep: Hashable { let actionID: String; let argument: AIActionArgument }
struct AIActionPlan: Equatable { let revision: Int; let steps: [AIPlanStep]; let allowsBackgroundExecution: Bool }

enum AIActionAvailability: Equatable { case ready, needsSetup, needsPermission }
typealias AIAvailabilitySnapshot = [String: AIActionAvailability]

enum AIApproval: Hashable { case plan(revision: Int, steps: [AIPlanStep]), step(AIPlanStep, revision: Int) }
struct AICapabilityLease: Equatable { let allowedActionIDs: Set<String>; let maxSteps: Int; let expiresAt: Date }

enum AIPlanValidation: Equatable { case valid(ValidatedPlan), needsApproval([AIApprovalRequest]), rejected([AIPlanViolation]) }
```

## Why the plan looks like this

These decisions came out of reading the code on 2026-09-14. Each task repeats
the one it depends on.

1. **The validator's result must be a type, not a list.** Today `validate`
   returns `[AIPlanViolation]`; any caller that forgets to check for an empty
   list runs a bad plan. A `ValidatedPlan` that only the validator can create
   turns that mistake into a compile error. *(Task 01)*
2. **Approval can never be part of model output.** Today each `AIPlanStep`
   carries `isExplicitlyApproved`, and plan steps are what a model produces — so
   a model could mark its own steps approved. Approvals must be a separate input
   that only the plan review interface creates. *(Task 02)*
3. **Approval binds to the plan's content, not a counter.** If a plan approval
   matched only a revision number, a changed step with an unchanged number would
   inherit approval. A plan approval therefore records the exact steps it
   covers; a step approval records the exact step. *(Task 02)*
4. **Risk ordering drives approval.** `AIActionRisk` is already `Comparable` but
   nothing used it. Reversible steps need the reviewed plan approved; anything
   above reversible needs its own approval. *(Task 02)*
5. **Availability comes from the live catalog.** `CommandBarCatalog` already
   decides, at runtime, whether a row is offered and whether it needs setup or a
   permission (`CommandBarEntry.trouble`). Copying feature and permission rules
   into AI descriptors would create a second answer that can drift. The
   validator takes a snapshot of the live answer instead. One difference is
   deliberate: the Command Bar *runs* a row that needs a permission, because
   running it raises the macOS prompt; a plan never does. *(Task 03)*
6. **Arguments resolve to row identifiers the catalog already builds.** Rows
   such as `action.soundOutput.<device>`, `app.<id>` and `folder.<path>` embed
   their target in the identifier. A step's target is valid only if that exact
   row is offered now, so a free-text path or an invented window simply does not
   resolve. *(Task 04)*
7. **The registry is an allow-list with an exhaustive decision.**
   `CommandBarCatalog.swift` is not in the test build (it needs live services),
   so tests read its source. Every row identifier must be either registered for
   AI or excluded with a written reason, so a new Command Bar row forces a
   deliberate AI decision. Rows the bar confirms can never be registered below
   destructive, and number ranges must match the row. *(Task 05)*
8. **Only enforce what exists.** The capability lease belongs in M1 because it
   limits validation. The context manifest has no consumer until a provider
   exists (M2), and run receipts and model-turn limits none until an executor and
   agent loop exist (M4). They move to those milestones rather than landing as
   unused types. *(Tasks 06 and 07)*
9. **Time is an input.** The validator takes `now`; it never reads the clock,
   so expiry is testable and deterministic. *(Task 06)*
10. **A guard is proven by breaking it.** Every guard gets a mutation entry that
    removes it and must make its named check fail.

## Constraints for later milestones

Recorded here so M2 and M4 do not rediscover them.

- **M2:** the Xcode 16.2 SDK used by CI has no `FoundationModels`. Wrap model
  code in `#if canImport(FoundationModels)` and weak-link the framework, or the
  Swift 6.0.3 CI job breaks. `tokenCount(for:)` needs macOS 26.4.
- **M2:** the context manifest (source, item count, size, boundary, provider,
  retention) arrives with the first provider request type.
- **M4:** the executor accepts only `ValidatedPlan`, re-validates against a
  fresh snapshot immediately before each step, and produces run receipts.
  Window identifiers are reused by macOS, so the review sheet shows each
  window's title and the executor re-checks it before acting.
- **M4:** the agent loop enforces a model-turn limit; the lease already caps
  steps and time.
- **M4:** refuse `toggle` steps that would switch off the feature hosting the
  AI surface (for example the Command Bar).
