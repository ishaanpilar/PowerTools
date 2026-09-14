# Task 07 — `AI-HARNESS.md` names the check behind every guarantee

| | |
| --- | --- |
| Depends on | Task 06 |
| Size | About 150 lines (mostly documentation) |
| Branch | `ai-harness/07-contract-docs` |
| Suite | `ai-harness` |

## Why

`docs/AI-HARNESS.md` was written before the code. It promises context manifests,
turn caps and receipts that nothing enforces, and it describes approval as a
flag. A document that states guarantees nothing enforces is the quietest kind of
defect: it reads as true.

This task rewrites the contract to describe exactly what tasks 01–06 built, and
adds two checks so the document and the tests cannot drift apart again:

- every guarantee in the document names a check message that exists in the
  tests;
- every `ai-harness` mutation names a check message that exists in the tests.

Guarantees not yet enforced move to an **Arrives later** table with their
milestone, instead of being stated as current.

It also closes M1.

## Read first

- `docs/AI-HARNESS.md` (current)
- `Sources/PowerTools/Services/AI/*.swift`
- `Tests/AIHarnessTests.swift`, `Tests/AIActionRegistryTests.swift`
- `Tests/mutation_checks.py`
- `docs/ai-harness/README.md`, "Why the plan looks like this"

## Change

### 1. Rewrite `docs/AI-HARNESS.md`

Keep the title and the opening paragraph's purpose. Use these sections, in
plain prose, short:

1. **Loop** — observe offered rows → model proposes a plan → the app assigns a
   revision → validate → review and approve → validate again → run
   (`ValidatedPlan` only) → report.
2. **Outcomes** — `.rejected`, `.needsApproval`, `.valid`, and that structural
   violations always win over approvals.
3. **Risk and approval** — the table from task 02.
4. **Availability** — the snapshot rules from task 03, including the deliberate
   difference from the Command Bar.
5. **Arguments** — numbers bounded by the row; targets resolve to row ids.
6. **Registry** — allow-list, exclusions with reasons, the three agreement rules.
7. **Lease** — allowed actions, steps, deadline, injected clock.
8. **Guarantees** — the table below.
9. **Arrives later** — the table below.
10. **Provider policy** — keep the existing paragraph.

**Guarantees table.** Keep this exact column order; the check reads the fourth
column. Wrap every check message in backticks, and put nothing else in
backticks in that column.

| # | Guarantee | Enforced by | Check | Mutation |
| --- | --- | --- | --- | --- |
| 1 | A plan with no steps never runs | Empty-plan guard in `AIPlanValidator` | `an agent cannot execute an empty plan` | empty plan becomes runnable |
| 2 | Only the validator creates a runnable plan | `ValidatedPlan`'s `fileprivate` initialiser | `only AIPlanValidator constructs a ValidatedPlan` | — |
| 3 | A runnable plan cannot be decoded into existence | No `Codable` on `ValidatedPlan` | `a ValidatedPlan cannot be decoded into existence` | — |
| 4 | A model cannot invent an action | Registry allow-list | `a model cannot invent an executable action` | — |
| 5 | A model cannot approve its own steps | `AIPlanStep` has no approval | `approval is never part of a model-produced step` | — |
| 6 | A plan approval never covers anything above reversible | Risk ordering in `approvalRequest` | `a plan approval never satisfies a destructive step`, `external and privileged steps need their own approval` | plan approval covers destructive steps |
| 7 | Approval is void once the plan changes | Approvals bound to steps and revision | `changing a step after approval voids the plan approval`, `a new plan revision voids earlier approvals` | plan approval ignores its steps |
| 8 | Approvals never override a structural problem | Outcome precedence | `approvals never override a structural violation` | — |
| 9 | Only rows the Command Bar offers now can run | Availability snapshot | `a row the Command Bar is not offering cannot be planned` | — |
| 10 | A plan never raises a permission prompt | `needsPermission` is rejected | `an approval cannot substitute for a macOS permission` | permission-blocked row treated as ready |
| 11 | Numbers stay within the row's range | `AIActionDescriptor.catalogID(for:)` | `an out-of-range number is rejected` | number range ignored |
| 12 | Free text cannot become a target | Row id resolution | `a free-text target cannot become a row` | — |
| 13 | Every Command Bar row has an AI decision | Registry exhaustiveness | `every Command Bar row is registered for AI or excluded with a reason` | catalog row left undecided |
| 14 | Rows the bar confirms are never registered as low risk | Registry risk floor | `an action the Command Bar confirms is never registered below destructive` | confirmed row registered as reversible |
| 15 | Registered number ranges match the row | Registry agreement | `registered number ranges match the Command Bar row` | keep-awake range drifts from its row |
| 16 | A run stops at its deadline | Lease | `a lease stops at its deadline` | expired lease still runs |
| 17 | A run uses only its leased actions | Lease | `a registered, approved action outside the lease is rejected` | lease ignored for registered actions |
| 18 | A plan cannot turn foreground work into background work | Descriptor flag | `a model cannot convert a foreground action into background work` | — |

**Arrives later table.**

| Guarantee | Milestone |
| --- | --- |
| Executors accept only `ValidatedPlan` and re-validate against a fresh snapshot before each step | M4 |
| Only the plan review interface creates `AIApproval` values | M4 |
| The availability snapshot is built from live `CommandBarCatalog` rows | M4 |
| Agent loops stop at a model-turn limit | M4 |
| Every run produces a receipt | M4 |
| Every provider request carries a context manifest, previewed before the first send | M2 |

### 2. `Tests/AIHarnessTests.swift`

Add two checks, reading files with `AIHarnessSource` (assert each file was read):

| Message | Rule |
| --- | --- |
| `every guarantee in AI-HARNESS.md names a check that exists` | In `docs/AI-HARNESS.md`, take the text between `## Guarantees` and the next `\n## `. For each table row that starts with a number (skip the header and `---` rows), split on `\|` and read the fourth column's backticked strings. Require at least 18 rows. Every message must appear, quoted as `"<message>"`, in `Tests/AIHarnessTests.swift` or `Tests/AIActionRegistryTests.swift`. List missing messages in the failure |
| `every AI harness mutation names a check that exists` | In `Tests/mutation_checks.py`, find each tuple whose group is `"ai-harness"` and take its last string. Require at least 10. Each must appear quoted in the same two test files |

Read the Python file as plain text (not with `AIHarnessSource.code`, which only
strips Swift `//` comments). A regular expression over the `MUTATIONS` tuples is
enough; if the file's shape makes that unreliable, stop and ask.

### 3. `Tests/mutation_checks.py`

```python
    ("contract names a missing check", "ai-harness", "docs/AI-HARNESS.md",
     "`an agent cannot execute an empty plan`",
     "`an agent can execute an empty plan`",
     "every guarantee in AI-HARNESS.md names a check that exists"),
```

### 4. Close M1

- In `docs/ai-harness/README.md`, mark every task done.
- In `docs/AI-PRODUCT-ROADMAP.md`, mark M1's findings 1–5 as resolved and M1 as
  complete, with the date.

## Done when

- `./build.sh --test-suite=ai-harness`, `./build.sh --test` and `./build.sh` pass.
- `python3 Tests/mutation_checks.py` passes with all eleven harness mutations.
- Every guarantee in `docs/AI-HARNESS.md` is either in the Guarantees table with
  a passing check, or in Arrives later.

## Out of scope

Any code change beyond the two checks. If writing the document reveals a
guarantee that tasks 01–06 did not actually enforce, stop and report it rather
than softening the wording.
