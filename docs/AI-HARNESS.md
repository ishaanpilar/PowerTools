# AI harness contract

This is the runtime contract for PowerTools AI features. It exists so
providers, prompts and UI can evolve without widening what an agent can do.
Read it with [the product roadmap](AI-PRODUCT-ROADMAP.md) and
[AGENTS.md](../AGENTS.md).

## Loop

observe offered rows → model proposes a plan → the app assigns a revision →
validate → review and approve → validate again → run (`ValidatedPlan` only) →
report.

The model chooses among rows the Command Bar is offering right now. It never
decides what those rows are, what they need, or whether it has been approved
to run them.

## Outcomes

`AIPlanValidator.validate` returns one of three outcomes:

- `.rejected([AIPlanViolation])` — a structural problem: an empty plan, an
  unregistered or duplicated step, a bad argument, a row the Command Bar isn't
  offering, an expired or exceeded lease.
- `.needsApproval([AIApprovalRequest])` — every step is otherwise runnable,
  but at least one still needs a person's approval.
- `.valid(ValidatedPlan)` — every step is runnable and approved. Only
  `AIPlanValidator` can produce a `ValidatedPlan`; nothing else in the app can
  construct one, and it cannot be decoded from data.

A structural problem always wins: if any step is rejected, the whole plan is
`.rejected`, even when every other step is approved.

## Risk and approval

| Risk | Example | Approval |
| --- | --- | --- |
| `readOnly` | Inspect a metric snapshot | None |
| `reversible` | Arrange windows, start a Keep Awake timer | The reviewed plan, or the step itself |
| `destructive` | Empty Trash, remove a Cleaner candidate | The step itself, specifically |
| `external` | Share a file, open an updater | The step itself, specifically |
| `privileged` | An Automation or administrator action | The step itself, specifically |

Approval is never part of a plan step: `AIPlanStep` names an action and its
argument, nothing else. `AIApproval` is created only by the (future) plan
review interface, and is bound to exact content: a plan approval names the
exact steps it covers at a specific revision, and a step approval names the
exact step at that revision. Editing a step, or reusing an old revision,
voids the approval that covered it.

## Availability

Whether a step can run comes from a snapshot of live Command Bar rows,
`AIAvailabilitySnapshot`, keyed by row id — not from a second, hand-maintained
list of features and permissions. A missing key means the Command Bar isn't
offering that row right now; `.needsSetup` and `.needsPermission` map
straight from `CommandBarEntry.trouble`.

One difference from the Command Bar is deliberate: pressing Return on a row
that still needs a permission runs it anyway, because that's what raises the
macOS prompt. A plan never does that — its side effects are only its approved
actions, and a permission prompt appearing mid-plan is neither. So the
validator rejects `.needsPermission` even when every approval is present.

## Arguments

A step's argument is typed: `.none`, `.integer` within the row's declared
range (optionally absent, if the row allows it), or `.entity(kind, id:)`. A
number outside its row's range, or an argument of the wrong shape, is
rejected before anything else about the step is checked. An entity argument
resolves to the literal Command Bar row id `"<action id>.<entity id>"`; if
the Command Bar isn't offering that exact row, the step is rejected as not
offered — free text never becomes a target just because it looks like one.

## Registry

`AIActionRegistry` is the allow-list: the only Command Bar rows an AI plan
may ever use. Nothing outside it can run, no matter what a model proposes.
Three rules keep it honest against the real Command Bar catalog, checked
from the catalog's own source text since the catalog itself needs live
services and isn't in the test build:

- every row in the catalog is either registered or excluded with a written
  reason, so a new row forces a decision;
- a row the Command Bar asks the person to confirm is never registered below
  `destructive`;
- a registered number range matches the row's own range exactly.

Until milestone M6 builds target-bound approval for destructive rows, the
registry offers only `reversible`, foreground actions.

## Capability lease

A run's actual authority is narrower than the registry: `AICapabilityLease`,
created by the app when a request starts, names which registered actions
this run may use, a step limit, and a deadline. A plan carries none of this
itself, so a model cannot widen its own limits. The validator takes the
current time as a parameter and never reads the clock itself, so a lease's
expiry is exact and testable.

## Guarantees

Each of these is enforced by a specific check, proven by a mutation that
removes the enforcement and confirms the check then fails.

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

This table is itself checked: every message above must exist, quoted, in
`Tests/AIHarnessTests.swift` or `Tests/AIActionRegistryTests.swift`
(`every guarantee in AI-HARNESS.md names a check that exists`), and every
`ai-harness` mutation in `Tests/mutation_checks.py` must name a check that
exists (`every AI harness mutation names a check that exists`).

## Arrives later

These are not enforced yet. Do not build against them until they land.

| Guarantee | Milestone |
| --- | --- |
| Executors accept only `ValidatedPlan` and re-validate against a fresh snapshot before each step | M4 |
| Only the plan review interface creates `AIApproval` values | M4 |
| The availability snapshot is built from live `CommandBarCatalog` rows | M4 |
| Agent loops stop at a model-turn limit | M4 |
| Every run produces a receipt | M4 |
| Every provider request carries a context manifest, previewed before the first send | M2 |

## Provider policy

Apple Foundation Models are preferred for supported on-device requests
(macOS 26 and later). Cloud providers are available from macOS 14 and require
a named provider, a Keychain-backed key supplied by the person, a visible
payload preview and a privacy-policy link. Local model servers must be
loopback-only. Claude Code is an external local connector: it owns its own
authentication and its own project-tool approvals. PowerTools AI neither
extracts its credentials nor passes `--dangerously-skip-permissions`.
