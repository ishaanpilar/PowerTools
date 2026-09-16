# PowerTools AI product roadmap

> **Status, 2026-09-16.** Owner decisions D1–D7 are recorded; D8 and D9 are
> open. `AGENTS.md` (now tracked), `CONTRIBUTING.md` and `docs/PRIVACY.md`
> have been rewritten for PowerTools AI. **M1 is complete:** the plan
> contract — `ValidatedPlan`, graded approval, live availability, typed
> arguments, the 23-action registry checked against the real Command Bar
> catalog, and the capability lease — is built, tested (61 `ai-harness`
> checks) and proven by 18 mutations, 11 of them the harness's own. It is not
> yet called by any executor; that is M4. See
> [docs/ai-harness/](ai-harness/README.md) for how it was built, task by
> task. **M2 is functionally complete:** AI text actions (rewrite, shorten,
> proofread, summarise, translate) run from the Command Bar against the
> on-device model, a cloud provider the person connects with their own key,
> or a local server — off by default, previewed before the first real send
> per provider, nothing sent or replaced without an explicit action (33,013
> total checks). Not verified: a macOS 14 Mac or VM with a live cloud
> provider (this Mac only runs one current macOS version); the milestone's
> eighth screenshot is a maintainer task, not yet captured. See
> [docs/ai-text-actions/](ai-text-actions/README.md) for how it was built,
> task by task.

1. [Decisions](#1-decisions)
2. [Where things stand](#2-where-things-stand)
3. [Execution plan](#3-execution-plan)
4. [Product strategy](#4-product-strategy)
5. [Agentic execution](#5-agentic-execution)
6. [Integrations and the Claude Code connector](#6-integrations-and-the-claude-code-connector)
7. [Evaluation, quality and release gates](#7-evaluation-quality-and-release-gates)
8. [Privacy](#8-privacy)
9. [Performance, resources and where AI runs](#9-performance-resources-and-where-ai-runs)

---

## 1. Decisions

### Decided on 2026-09-14

| # | Topic | Decision |
| --- | --- | --- |
| D1 | Platforms | The app and every utility support macOS 14. On-device AI (Apple Foundation Models) and AI onboarding require macOS 26. |
| D2 | Cloud providers | Available from the first AI release, on macOS 14 and later, with the person's own API key. |
| D3 | Name and identity | The public name is **PowerTools AI**: an independent open-source project, not affiliated with Vorssaint and not contributing to or tracking it. The README credits the project it is built on. Per-file copyright notices stay, as GPL-3.0 requires. |
| D4 | Scope | `CONTRIBUTING.md` is rewritten with AI as a core part of the product, and with its limits. |
| D5 | Languages | English first. Translation is milestone M5. |
| D6 | Agent rules | `AGENTS.md` is tracked in git. `docs/AI-CONTRIBUTIONS.md` was merged into it and removed. |
| D7 | Review | The maintainer reviews every AI and agent-assisted change. |

### Open

| # | Decision | Recommendation | Reasoning | Blocks |
| --- | --- | --- | --- | --- |
| D8 | Standalone identity: bundle identifier, release repository, signing identity, app icon | Give PowerTools AI its own bundle identifier and release repository before its first public release | While it uses `com.powertools.utils`, macOS treats it as the same app as any PowerTools install: shared settings, shared permission grants, and an update check against earlier PowerTools releases. No PowerTools AI user exists yet, so changing identity now costs nothing; after release it resets everyone's permissions. This replaces the earlier "branding only" choice, which assumed a rename rather than a standalone app. | First release |
| D9 | Screenshot links, recording links and in-app feedback | Remove these controls, and the placeholder support, chat and social links, before release | They all point at `*.powertools.invalid`, a reserved domain that never resolves; there is no service behind them. The privacy policy says the app uploads none of this, which stays true only while they cannot work. Running a service instead means operating a server, which `CONTRIBUTING.md` rules out. | First release |
| D10 | Bundle our own model inside the app? | No. Use Apple's on-device model where available and the person's chosen cloud provider or local server otherwise | A bundled model adds gigabytes to a 50 MB app, puts its memory and GPU load inside PowerTools, and adds a dependency to maintain. Apple's model costs the app about 9 MB and runs in a system process on the Neural Engine. See [section 9](#9-performance-resources-and-where-ai-runs). | M2 |

---

## 2. Where things stand

### Verified in this repository

Checked against the working tree on 2026-09-14.

| Item | State | Evidence |
| --- | --- | --- |
| `Services/AI/AIHarnessContracts.swift` | Pure types and `AIPlanValidator`; no executor calls it | Referenced only by `Tests/AIHarnessTests.swift` |
| `Tests/AIHarnessTests.swift` | Nine checks, passing | `./build.sh --test`: `ai-harness: OK (9 checks)`; `TESTS OK (32524 checks)` |
| Agent rules | `AGENTS.md` trackable; its ignore rule removed | `.gitignore` |
| Toolchain | macOS 26.5 SDK with `FoundationModels.framework` | `xcrun --sdk macosx --show-sdk-path` |
| Development Mac | macOS 26.5.2 (25F84), arm64 | On-device AI is testable here; the macOS 14 cloud path needs a macOS 14 Mac or virtual machine |
| Foundation Models floor | macOS 26.0 | `@available(iOS 26.0, macOS 26.0, visionOS 26.0, *)` in the SDK interface |
| App floor | macOS 14 | `Package.swift`: `.macOS(.v14)` |
| Action catalog | `CommandBarCatalog.swift`: 1,671 lines, 74 `CommandBarEntry(` construction sites; five call sites pass `confirmationPrompt`, three `numericRange` | `grep` |
| Features and permissions | 58 `AppFeature` cases, 11 `AppPermission` cases | `Core/FeatureCatalog.swift` |
| Name footprint | "PowerTools" in 1,068 Swift string literals and 120 times in localized `InfoPlist.strings` | `grep` |
| Placeholder services | Share links and feedback use `screenshots.powertools.invalid`; support, chat and social links use `powertools.invalid` | `ScreenshotSharingSupport.swift`, `RecordingSharingSupport.swift`, `FeedbackService.swift`, `Core/AppInfo.swift` |

Foundation Models facts read from the SDK interface:

- `SystemLanguageModel.Availability` is `.available` or `.unavailable(reason)`,
  with reasons `deviceNotEligible`, `appleIntelligenceNotEnabled` and
  `modelNotReady`.
- `LanguageModelSession` offers `respond(to:generating:)` for `Generable` types
  and `streamResponse`.
- `LanguageModelSession.GenerationError` includes `exceededContextWindowSize`,
  `assetsUnavailable`, `guardrailViolation`, `unsupportedGuide`,
  `unsupportedLanguageOrLocale`, `decodingFailure`, `rateLimited` and
  `concurrentRequests`.

### Findings

| # | Finding | Status |
| --- | --- | --- |
| 1 | The harness document promises more than the code enforces | Resolved 2026-09-14: `AI-HARNESS.md` rewritten (task 07); every guarantee names its enforcing check |
| 2 | A second action registry is forming beside `CommandBarCatalog` | Resolved 2026-09-14: `AIActionRegistry` derives its 23 rows from the catalog and is checked against its source (task 05) |
| 3 | Plans validate which action runs, not what it acts on | Resolved 2026-09-14: typed `AIActionArgument`/`AIArgumentKind`, resolved to real Command Bar row ids (task 04) |
| 4 | One Boolean approves every risk class, and is not bound to the approved plan | Resolved 2026-09-14: `AIApproval` graded by risk, bound to exact steps and revision (task 02) |
| 5 | Nothing forces execution through the validator | Resolved 2026-09-14: `ValidatedPlan`'s `fileprivate` initialiser (task 01) |
| 6 | On-device AI reaches only macOS 26 | Resolved by D1 and D2: cloud providers serve macOS 14 and 15 |
| 7 | The roadmap conflicted with the project's scope rules | Resolved: `CONTRIBUTING.md` rewritten |
| 8 | Agent rules were not in the repository | Resolved: `AGENTS.md` tracked |
| 9 | The rename touches identifiers, not only display text | Open → M0.2–M0.4 and D8 |
| 10 | The earlier roadmap had two sequences that disagreed | Resolved: one plan below |
| 11 | The old privacy policy described upload services that do not exist, and left out Radial Menu icon fetching | Policy resolved; the controls remain → D9 |

**Finding 1.** `AI-HARNESS.md` specifies context manifests, capability leases,
graduated approval and receipts. The code checks action identity, installed
feature, granted permission, one approval flag and background eligibility.
Until M1 closes the gap, the document states guarantees nothing enforces.

**Finding 2.** `CommandBarEntry` already carries most of what
`AIActionDescriptor` re-declares, with nothing requiring the two to agree:

| Harness concept | Already in `CommandBarEntry` |
| --- | --- |
| Stable action identity | `id`, `stableKey` |
| Deterministic executor | `run: (Int?) -> Void` |
| Typed, bounded argument | `numericRange`, `numericIsOptional` |
| Destructive confirmation | `confirmationPrompt` |
| Feature not set up | `Trouble.needsSetup(featureTitle:page:)` |
| Permission missing | `Trouble.needsPermission` |
| Same behaviour from every entry point | `needsPrompt` |

The AI registry should derive from the catalog and add only a risk class and
background eligibility. One difference is deliberate and must survive: the bar
runs a command whose permission is missing, because that raises the macOS
prompt; the AI validator refuses, so a plan never raises a prompt as a side
effect.

**Finding 3.** `AIPlanStep` is an action ID and a Boolean. Real steps need
targets — a window, a snippet, a folder, a number — and targets are where
injected content does damage. The duplicate rule is also wrong once targets
exist: the same action on two different targets is legitimate.

**Finding 4.** The validator separates `readOnly` from everything else, so
`external` and `privileged` are treated like `reversible`. `isExplicitlyApproved`
is not tied to a plan revision, so a plan whose targets change after approval
still validates. `AIActionRisk` conforms to `Comparable`, but nothing uses the
ordering.

**Finding 5.** `validate` returns `[AIPlanViolation]`; a caller that forgets to
check it executes anyway. Bypass should be a compile error.

**Finding 9.** Many of the 1,068 literals are defaults keys, Application Support
paths, Keychain service names and identifiers used by cleanup scripts. Renaming
them discards stored settings. No own-data path derives from `CFBundleName` (its
uses read other apps' bundles), so the display name can change safely, but the
literals must be classified one by one.

---

## 3. Execution plan

### How work is cut

- One pull request per slice, aiming under about 200 changed lines.
- Every guard ships with a harness check that passes with the guard and fails
  with it removed.
- Every slice runs `./build.sh`, `./build/PowerTools --selftest` and
  `./build.sh --test`; UI slices must pass the full build.
- User-visible slices are verified on a real Mac, recording the macOS version,
  hardware, Apple Intelligence state, provider and permissions.
- A milestone ends at its exit criteria, not on a date.
- The maintainer reviews every slice (D7).

```text
M0 identity and release readiness ─┐
                                   ├─> M2 first AI feature ─> M3 single-context ─> M4 supervised ─> M5 languages ─> M6 ecosystem
M1 enforceable contract ───────────┘   on device + cloud      + AI onboarding       agent
                                        first public release
```

M0 and M1 run in parallel. The M4 evaluation corpus is written alongside M3.

### M0 — Identity and release readiness

**Done on 2026-09-14:** `AGENTS.md` rewritten and tracked; `CONTRIBUTING.md`,
`docs/PRIVACY.md`, `README.md`, `CHANGELOG.md` and `TRADEMARKS.md` rewritten for
an independent PowerTools AI, with credits in the README;
`docs/AI-CONTRIBUTIONS.md` merged into `AGENTS.md`; `docs/UPSTREAM-CHANGELOG.md`,
`docs/demo.gif` and the old README images removed. The marketing name
**PowerTools AI** applied to the English interface, `Info.plist` names and
permission prompts, the Finder extension, `build.sh` display names and every
document; the code name stays `PowerTools`.

| Slice | Work | Files |
| --- | --- | --- |
| 0.1 | Decide D8 and D9 | this document |
| 0.2 | Add a check that identifiers (defaults keys, support paths, Keychain services, audio device names, bundle and URL identifiers, `.app` name) stay `PowerTools` unless D8 changes them | new harness check; `Tools/uninstall.sh`, `Tests/PreferenceCleanupTests.sh` reviewed |
| 0.3 | ~~English display rename~~ — done. Left as code names on purpose: thread names, log messages, power-assertion names, the `PowerTools Mixer` and `PowerTools Recorder` audio devices, and the release-notes boilerplate matched by `ReleaseNotes.swift` and `release.yml` | — |
| 0.4 | Apply D8: bundle identifier, update repository, signing identity, icon | `Resources/Info.plist`, `build.sh`, `Tools/`, `.github/workflows/`, `Services/Update/UpdateService.swift` |
| 0.5 | Apply D9: remove share-link, recording-link and feedback controls, placeholder links and their strings | `Services/QuickTools/ScreenshotSharingSupport.swift`, `Services/Recorder/RecordingSharingSupport.swift`, `Services/Feedback/`, `UI/Feedback/`, `Core/AppInfo.swift` |
| 0.6 | ~~README for PowerTools AI~~ — done; revisit at release so it describes only what ships | `README.md` |
| 0.7 | Capture new screenshots to the shot list below and add them to the README | `docs/assets/readme/`, `README.md` |
| 0.8 | Bring remaining documents in line | `SUPPORT.md`, `SECURITY.md`, `docs/PERMISSIONS.md`, `docs/TROUBLESHOOTING.md`, `.github/` templates |
| 0.9 | Remove inherited media: the update showcase clip and its release-workflow step, in-app highlight images, the Discord mark | `ReleaseAssets/`, `Services/Update/UpdateShowcaseMedia.swift`, `.github/workflows/release.yml`, `Resources/Images/` |

**Shot list.** Seven images, captured by the maintainer; the old README images
have been removed, so add these as new files. English, light
appearance, 2×, plain wallpaper, with no personal names, window titles,
clipboard contents or file names visible. The four panel shots share one width.

| Slot | File | Capture |
| --- | --- | --- |
| Panel 1 | `panel-mixer.png` | Menu panel, Sound: several apps, one boosted past 100% |
| Panel 2 | `panel-system.png` | Dashboard: greeting header, health summary, CPU and memory cards, one expanded |
| Panel 3 | `panel-controls.png` | Windows and Dock controls |
| Panel 4 | `panel-utilities.png` | Utilities: Cleaner, Homebrew, media tools, clipboard |
| Features | `features-hub.png` | Settings › Features: installed and uninstalled items with energy badges |
| Switcher | `window-switcher.gif` | App Switcher with live thumbnails, three or more windows |
| Permissions | `permissions.png` | The permissions page |

M2 adds an eighth shot: a Command Bar text action.

**Exit:** D8 and D9 decided and applied; the identifier check passes; the
English interface and bundle read PowerTools AI; nothing links to `.invalid`;
every document reads PowerTools AI. Nothing is released before M2.

### M1 — Make the contract enforceable

**Goal:** every guarantee in `AI-HARNESS.md` is enforced by a type or a check
before any model output exists. Pure Swift: no interface, model or network.

**Implementation specs:** [docs/ai-harness/](ai-harness/README.md), one file per
task, written on 2026-09-14 after reading the code. Work them in order.

| Task | Change | Replaces slices |
| --- | --- | --- |
| [01](ai-harness/01-validated-plan.md) | `AIPlanValidation` outcome and `ValidatedPlan`, which only the validator can create | 1.1 |
| [02](ai-harness/02-approvals.md) | Approvals as a separate input from the review interface, bound to exact steps and revision, graduated by risk ordering | 1.4, 1.5 |
| [03](ai-harness/03-live-availability.md) | Availability from a snapshot of live Command Bar rows replaces feature and permission fields | 1.2 (first half) |
| [04](ai-harness/04-typed-arguments.md) | Typed arguments; targets resolve to row ids such as `app.<id>` | 1.3 |
| [05](ai-harness/05-action-registry.md) | Production allow-list of 23 reversible rows; every catalog row registered or excluded with a reason | 1.2 (second half) |
| [06](ai-harness/06-capability-lease.md) | Lease: allowed actions, step limit, deadline, injected clock | 1.6 (partly) |
| [07](ai-harness/07-contract-docs.md) | `AI-HARNESS.md` lists each guarantee with its check and mutation | 1.8 |

**What changed from the original slices, and why:**

- **Approval was inside model output.** `AIPlanStep.isExplicitlyApproved` let a
  model mark its own steps approved; task 02 removes it.
- **Descriptors cannot be derived from `CommandBarCatalog` in tests.** The
  catalog needs live services and is not in the test build, and its ids are
  string literals, not `stableKey` data. Availability therefore comes from the
  live rows at run time (task 03), and the registry is checked against the
  catalog's source (task 05).
- **Plan approval binds to the steps themselves**, not a digest or a revision
  number alone, so whoever assigns revisions cannot carry approval across an
  edit. No hashing is needed.
- **Built only where used.** The context manifest (old 1.7) moves to M2 with the
  first provider request. Run receipts and the model-turn limit (old 1.6) move to
  M4 with the executor and agent loop.

**Exit:** all checks pass, and `python3 Tests/mutation_checks.py` proves each
guard by making its named check fail. **Reached 2026-09-14:** all seven tasks
landed on `ai-harness/01` through `ai-harness/07`; `ai-harness` suite at 61
checks, full suite at 32,791, `mutation_checks.py` at 18/18 (11 `ai-harness`).

### M2 — First AI feature: text actions, on device and in the cloud

**Goal:** one useful feature with no side effects that proves both provider
paths, key handling, the pre-send preview, availability handling, privacy and
Feature Hub integration. This is the first public release of PowerTools AI.

It comes first because `CommandBarSelection.swift` already reads the selected
text, the result is shown for the person to copy or place, and no plan executor
is involved.

| Slice | Work |
| --- | --- |
| 2.1 | `AppFeature` case for AI with Feature Hub copy and energy badge; uninstalled, it loads no framework and makes no connection |
| 2.2 | A provider protocol with two implementations from the start — justified because both ship in this milestone: Apple on-device (`@available(macOS 26, *)`) and HTTP; a capability matrix for text, typed output, streaming, context size and vision |
| 2.3 | An OpenAI-compatible adapter covering DeepSeek, OpenAI and loopback model servers (Ollama, LM Studio), and an Anthropic adapter; HTTPS required except on loopback; timeouts and cancellation |
| 2.4 | Keys in Keychain only; a check that defaults and settings exports contain no key |
| 2.5 | AI settings: On this Mac, a cloud provider or a local server; shows the endpoint and the provider's privacy policy link; tests the connection |
| 2.6 | Availability and failure states: macOS earlier than 26, `deviceNotEligible`, `appleIntelligenceNotEnabled`, `modelNotReady`, each `GenerationError`; no provider, invalid key, quota or rate limit, offline, HTTP errors, cancellation |
| 2.7 | Context manifest (source, item count, size, local or remote boundary, provider, retention) on every provider request; pre-send preview built from it on the first send of each content type; cancel on every request |
| 2.8 | Command Bar actions on the selection: rewrite, shorten, proofread, summarise, translate; Copy, Replace selection, Cancel |
| 2.9 | English strings; non-English catalogs repeat the English text |
| 2.10 | Confirm `PRIVACY.md` matches behaviour; add the Command Bar screenshot; release |

**Must verify, not assume:** whether a request from the menu bar's
non-activating panel is rate limited as background work; each provider's current
API shape and its retention and training terms.

**Exit:** verified on macOS 26.5.2 arm64 with Apple Intelligence on and off,
and on a macOS 14 Mac or virtual machine with a cloud provider; on-device use
makes no connection, confirmed with a network monitor; a cloud request contains
exactly the previewed content, confirmed with a local HTTPS proxy; non-loopback
addresses are refused for local servers; keys absent from defaults, exports and
logs; an uninstalled feature loads nothing.

**Reached 2026-09-16:** all seven tasks landed on `ai-text-actions/01` through
`07`; full suite at 33,013 checks, `mutation_checks.py` still 18/18. Verified
live on this Mac (macOS 26+, Apple Intelligence on): the feature installs and
uninstalls cleanly; the settings page connects and tests on-device, DeepSeek,
OpenAI, Anthropic, a custom endpoint and a local server; all five Command Bar
actions appear only with a selection and the feature installed and run a real
on-device generation end to end, previewed once per provider, into a panel
whose Copy and Replace both require an explicit press. On-device network
isolation and cloud request contents were confirmed structurally and by
mocked-request tests respectively, not by a live network monitor or HTTPS
proxy (see `docs/ai-text-actions/README.md`'s task 07 notes for why). Not
verified: a macOS 14 Mac or VM with a live cloud provider - only one machine,
running one current macOS version, was available. The milestone's eighth
screenshot is a maintainer task per this document's own M0 shot list and
was not attempted.

**Not in M2:** plans, actions beyond Replace, clipboard or capture context,
onboarding.

### M3 — Single-context features and AI onboarding

One pull request each, in rising order of risk, reusing M2's providers,
availability and failure handling.

| Slice | Feature | Context | Side effect |
| --- | --- | --- | --- |
| 3.1 | Scratchpad: summary, action items, structure | Active tab | Writes a new tab; never overwrites |
| 3.2 | Clipboard item transforms | One selected item | Adds a clip; the original is untouched |
| 3.3 | App Updates release-note summaries | Notes already fetched | None |
| 3.4 | "Why is my Mac busy?" | Local metric snapshot; each claim links to its metric | None |
| 3.5 | Screenshot alt text and OCR cleanup | Current capture; Vision OCR first; images go only to a vision-capable provider, after preview | None |
| 3.6 | Ask PowerTools AI | Bundled documentation, cited and deep-linked | Proposes settings through a review sheet |
| 3.7 | AI onboarding: "Make it personal" | The sentence typed during setup; macOS 26, on device only; not kept | Suggestions go through the existing Feature Hub install flow; "Choose myself" equally prominent |

Onboarding stays on device (D1) so nobody is asked for an API key before they
have set the app up.

**Exit:** each feature keeps its non-AI path and has a check that instructions
embedded in its content — clipboard text, notes, release notes, recognised
text — change nothing about its behaviour.

### M4 — Supervised agent: intent, validated plan, execution

**Starts when:** M1 is complete and the evaluation corpus exists.

| Slice | Work |
| --- | --- |
| 4.1 | Synthetic corpus of at least 200 intents: ambiguous, permission denied, feature uninstalled, destructive attempts, and injection through clipboard text, screenshots, file names and release notes |
| 4.2 | A `Generable` plan type, and an equivalent JSON schema for HTTP providers, constrained to a shortlist of at most 10 candidate actions retrieved locally from the derived registry. The full 74-action list costs 1,761 tokens, 43% of the on-device context, and the on-device model picked wrong actions from it in testing (section 9) |
| 4.3 | Command Bar "Ask" mode: plan review with per-step toggles, reasons and requirements; the button reads "Run N approved actions" |
| 4.4 | Executor path from `ValidatedPlan` to `CommandBarEntry.run`, re-validating against a fresh availability snapshot before each step; each effect read back; `AIRunReceipt`; Stop prevents further steps; a model-turn limit on the agent loop |
| 4.5 | `readOnly` and `reversible` actions only |
| 4.6 | First jobs: create a workspace; capture preflight |

Plans from cloud providers pass the same validator. Sending a plan request to a
cloud provider reveals the available action names, so they appear in the
pre-send preview.

**Exit:** full schema, registry and approval compliance across the corpus, per
provider; no unregistered, unapproved or out-of-lease execution; the injection
set changes no authority; Stop verified mid-plan.

### M5 — Languages

| Slice | Work |
| --- | --- |
| 5.1 | Translate strings added in English into the supported locales |
| 5.2 | Localized display name and permission prompts in `Resources/*.lproj` |
| 5.3 | Per-language AI availability: on-device AI hidden where the model does not support the language |
| 5.4 | A check that no translated catalog still repeats English text for fields added during the English-first phase |

### M6 — Ecosystem and advanced work

Each item is gated on its own decision:

- Destructive, external and privileged steps in agent plans, using M1's
  target-bound approvals.
- Routines and Workspace Profiles, with background runs under their own policy.
- Five to ten App Intents for safe actions.
- A local PowerTools AI MCP server, read-only and dry-run first.
- The Claude Code connector: experimental, separately installed, with
  Anthropic's plan terms re-checked when built.
- Personal Knowledge Search, including semantic clipboard search, as its own
  feature because the index has a storage cost.
- Capture Intelligence for recordings, the Mac Health Coach, Cleaner and
  Uninstaller explanations.

---

## 4. Product strategy

### Product position

PowerTools AI is a local-first Mac productivity layer: one command surface that
understands intent, proposes a safe plan using tools the person already
installed, and performs only the actions they approve. It is not an
always-listening assistant, a cloud dashboard, or an agent with invisible
authority.

**AI makes each feature easier to discover, faster to use, and safer to
operate.** It is not a chatbot bolted onto the menu bar. Deterministic services
remain the source of truth and the execution layer; AI sits above them as
planner, interpreter, summariser and recommender.

### Operating principles

1. **Local first, explicit always.** Apple's on-device model is the default
   where available. Elsewhere a person may connect a cloud provider with their
   own key, or a model server on their Mac. Nothing reaches a cloud provider
   until the person has chosen it and seen what leaves the Mac.
2. **No background inference from sensitive content.** Clipboard history,
   screenshots, recordings, window and file names, installed apps and usage
   history are never silently sent to any model.
3. **Proposal before side effect.** AI may summarise, classify, search and
   draft. It may not quit apps, delete or move files, install software, share,
   change settings or run scripts without a confirmation naming target and
   effect.
4. **Grounded tools, bounded authority.** A model selects registered, typed
   actions whose arguments resolve to app-enumerated entities. It never gets a
   shell, arbitrary AppleScript, the full filesystem, keys or unrestricted
   preferences.
5. **Model output is never a permission system.** macOS permissions, feature
   installation and the person's confirmation remain authoritative.
6. **Useful without AI.** Every feature keeps its non-AI workflow.

Foundation Models supports on-device guided generation into `Generable` types,
streaming and tool calling, which suits typed plans and extraction. Its context
window is fixed (Apple documents 4,096 tokens; the SDK reports overflow as
`exceededContextWindowSize`), so long content needs chunking.

### The AI runtime

AI ships as an installable Feature Hub item. Uninstalled, it loads no model,
makes no connection and keeps no process alive.

| Component | Purpose | Arrives |
| --- | --- | --- |
| Plan contract | `ValidatedPlan`, typed arguments, target-bound approval, lease, receipt | M1 |
| Action registry | Derived from `CommandBarCatalog`, adding risk class and background eligibility | M1 |
| Providers | Protocol and capability matrix; Apple on-device, OpenAI-compatible (cloud and loopback) and Anthropic adapters | M2 |
| Consent and settings | Provider choice, keys, pre-send preview, global switch | M2 |
| Context broker | Minimised, selected context with a manifest and optional local activity log | M3 |

### Provider ladder

| Preference | Provider | Best for | Data boundary | Rule |
| --- | --- | --- | --- | --- |
| 1 | Apple Foundation Models (macOS 26) | Text transforms, extraction, intent to plan | On device | Default where available; On-device badge |
| 2 | Local server: Ollama, LM Studio | Larger local models, vision | Loopback only | Person supplies endpoint and model; non-loopback refused |
| 3 | Cloud: OpenAI-compatible (including DeepSeek), Anthropic (macOS 14) | Long context, harder reasoning, vision; the only option on macOS 14 and 15 without a local server | The chosen provider receives exactly the previewed request | Off by default; key in Keychain |
| 4 | Bundled model, later | On-device on any macOS | On device | Deferred: download size, licensing, support |

Build adapters and a capability matrix, not a "DeepSeek mode", so a request only
goes to a provider whose capabilities fit it and vendors can change without
changing workflows.

### Availability

- The app stays on macOS 14; a missing model never blocks a non-AI feature.
- Interface states: **On-device ready**, **Turn on Apple Intelligence**, **Model
  downloading**, **This Mac is not eligible**, **On-device AI needs macOS 26**,
  **Connect a provider**, **Local model ready**, **Cloud provider connected**,
  **Check your API key**, **Offline**, **This task needs vision or longer
  context**.
- Every AI affordance sits beside a deterministic alternative.
- Use guided generation or a JSON schema for intents, plans, classifications and
  extraction, never parsing free-form model text.

### Interaction pattern

`select context → choose task → see provider and data boundary → receive a
streamed result or typed plan → review target and effect → confirm or edit →
run deterministic action → undo or show result`

A small spark icon marks only transformations, suggestions and the Command
Bar's Ask mode.

### First launch

After the Essentials, Windows and Battery and quiet choice:

- **On macOS 26:** an optional **Make it personal** card. "Tell PowerTools AI
  what you do" returns an editable setup recipe — features, shortcuts,
  permissions and reasons — from on-device extraction, inferring nothing from
  browsing, files, clipboard or usage. "Choose myself" stays equally prominent.
- **On every macOS:** **Where should AI run?** — on this Mac (macOS 26), my local
  model, a cloud provider with my key, or not now. Cloud is described as a
  connection with its own terms and costs, not an upgrade.

AI explains permissions — why each is needed, what works without it — and never
pressures anyone into granting one. **Ask PowerTools AI** answers from bundled
documentation with citations, and proposes settings only through a review sheet.

### Opportunity map for existing features

#### Command, notes, clipboard and text

| Surface | AI capability | Context | Guardrail |
| --- | --- | --- | --- |
| Command Bar | Natural language to a typed plan | Derived registry and narrow live tools | Plan and confirmation for anything not read-only |
| Command Bar | Intent-aware search across commands, settings, snippets, captures, folders | Local index with keyword fallback | Only enabled scopes; no full-disk index |
| Command Bar | Suggestions for the current app and selection | Active app menu and selection, on invoke | No passive capture or profiling |
| Clipboard History | Semantic retrieval, grouping, titles, tags | On-device index, opt-in per type | Ignored apps and sensitive rules respected |
| Clipboard History | Transform a chosen clip | Selected clip | Explicit selection; preview before cloud |
| Snippets | Draft from intent, variants, variables, trigger conflicts | Snippet library | Never overwrites; preview and diff |
| Scratchpad | Summary, decisions, action items, drafts, templates | Active tab | No sending or deletion |
| Copy Text from Screen | OCR cleanup, tables to CSV, translation, explain an error | Selected capture | Preview before cloud |
| Clean URL | Explain tracking parameters | URL only | Never fetches without a visible choice |

#### Capture, images, recordings and media

| Surface | AI capability | Context | Guardrail |
| --- | --- | --- | --- |
| Screenshot editor | Title, alt text, redaction and blur candidates, labels | Current image | Redactions never auto-applied |
| Scrolling screenshots | Header and footer detection, crop suggestions, summaries | Current capture | Original preserved |
| Screen recorder | Transcript, chapters, summary, action items | Recording after Stop | Never during recording by default |
| Video editor | Silence cuts, click highlights, chapters, captions | Chosen recording | Suggestions become editable markers |
| Camera preview | Framing and lighting guidance | Live frames, locally | Off by default; no retention or identity scoring |
| Image conversion | Content-aware crop, accessible names and alt text | Selected images | Output paths shown |
| GIF tool | Best loop in a range, caption | Selected segment | Person keeps export decision |
| QR and color picker | Explain a QR payload; palette to design tokens | Selected capture | Links still need a click |

#### Files, cleanup, installs and updates

| Surface | AI capability | Context | Guardrail |
| --- | --- | --- | --- |
| Shelf | Label and group items; suggest destination | Shelf items | No automatic moves; paths hidden from cloud by default |
| Finder tools | Request to reviewable batch rename or move | Explicit selection | Before and after list with collisions |
| Disk image installer | Explain provenance, permissions, bundled extras | Image metadata | No trust verdict |
| Cleaner | Explain category, size, consequence; conservative recommendation | Scan metadata, minimised paths | No deletion from model confidence |
| Messaging downloads | Cluster media; propose retention rules | Selected items | Rules preview on samples first |
| Uninstaller | Group leftovers by certainty; flag data worth keeping | Bundle identifiers and paths | Nothing selected because a model said so |
| App updates | Summarise release notes by security, fixes, features | Notes already fetched | Never claims an update is safe |
| Homebrew manager | Intent to search; explain packages and risks | Brew results | Exact package reviewed |
| File search | Semantic search in configured folders | Configured folders, local index | Folder opt-in |

#### Windows, input and automation

| Surface | AI capability | Context | Guardrail |
| --- | --- | --- | --- |
| App Switcher, Dock Preview | Find windows by task meaning | Titles and app names | No background inspection of window content |
| Window Layout | Named layout from an intent | Display geometry, requested apps | Preview; ask before moving |
| Radial menu, Quick panel | Draft a profile from a goal | Registry and active app | Never reorders a saved profile silently |
| Quick toggles | Explain consequences; build routines | Selected actions | Dry run; per-step confirmation where needed |
| Shortcuts, Super Key | Conflict-free suggestions | Installed and reserved shortcuts | No silent reassignment |
| Mouse and keyboard tools | Settings from an opt-in calibration | Deliberate test input | No key logging |
| Focus follows mouse, Dock clicks, Quit protection | Explain conflicts; propose exceptions | Settings, app names | No behavioural inference |

#### Sound, display, energy and system health

| Surface | AI capability | Context | Guardrail |
| --- | --- | --- | --- |
| System Monitor | "Why is my Mac busy?" | Local snapshot and history | Each claim linked to a metric; no process killed without confirmation |
| Alerts | Explain an alert; suggest a reversible fix | Triggering metrics | No hardware diagnosis |
| Fan control | Explain and sanity-check a curve | Sensor values | AI never controls fans |
| Battery, Keep Awake | Named timed sessions; explain drain | Power state | Timer and Stop always visible |
| Displays | Named presets; explain arrangement | Display metadata | No camera analysis |
| Audio tools | "Why can't I hear this?"; audio scenes | Routing metadata | No microphone processing |
| Network | Explain speed-test results | Local counters | No packet inspection |

#### Support and settings

| Surface | AI capability | Context | Guardrail |
| --- | --- | --- | --- |
| Settings | Natural-language finder, explainer, "apply this setup" plan | Setting metadata | Every change reviewed; no secrets shown |
| Feature Hub | Recommend features from a goal | Feature catalog | Editable, no profiling |
| Troubleshooting | Documentation assistant with citations | Bundled docs | Says "I don't know" rather than invent |
| Privacy | Explain a request's content, provider and terms | Request manifest | Shown on first cloud use of each content type |

### New AI-native features

1. **PowerTools AI Agent** — the Ask mode of the Command Bar, returning a
   compact plan with a reason and requirements per step and a final "Run 3
   approved actions."
2. **Routines** — saved, inspectable workflows of existing actions. The editor
   is the product; generation fills it faster.
3. **Personal Knowledge Search** — an opt-in local index over configured
   folders, clipboard history, notes and screenshot OCR, answering with sources.
4. **Capture Intelligence** — one post-capture sheet: extract, summarise, action
   items, redaction suggestions, describe for accessibility, find later.
5. **Mac Health Coach** — evidence-backed explanations with a reversible next
   step and a source drawer of metrics.
6. **Workspace Profiles** — named modes of layout, audio, Keep Awake and
   toggles, drafted by AI and saved by the person.

### What not to build

- An always-on screen, microphone, keyboard or clipboard observer.
- A general computer-use agent with unrestricted Accessibility or shell access.
- AI-driven deletion, process killing, file moves, installs, sharing or sending.
- Emotion, attention, productivity-score or employee-monitoring features.
- An account, a project-run server, prompt collection or telemetry.
- A separate chat window without the Command Bar's typed actions.

---

## 5. Agentic execution

### Execution model

| Mode | May do | Example | Confirmation | Arrives |
| --- | --- | --- | --- | --- |
| Answer | Read narrow, registered context and return grounded guidance | "Why is battery drain high?" | None; sources shown | M3 |
| Plan | Assemble typed steps without changing anything | "Set me up to record a tutorial" | Review the plan | M4 |
| Run reviewed plan | Execute checked steps one at a time | Open apps, arrange windows, start Keep Awake | Plan approval plus per-step rules | M4 reversible; M6 destructive |
| Watch a bounded job | Follow a known job within preset rules | Tell me when compression finishes | Explicit start and stop | M6 |

Each run holds a capability lease — declared tools, files or folders, a turn cap
and a deadline — and a Stop button that prevents further calls immediately. The
agent receives facts from services, never direct filesystem or shell access.

### Good agentic jobs

| Job | Tools | Hard boundary |
| --- | --- | --- |
| Create a workspace | Launch apps, folder search, window layout, audio, Keep Awake, toggles | Opens nothing unrelated; changes no unlisted setting |
| Tutorial capture | Capture preset, recorder, Shelf, editor, export | Person starts, stops and approves every export |
| Tidy a project folder | Explicit folder, duplicates, conversion, rename proposal | Stages a reviewable plan only |
| Investigate poor performance | Metrics, processes, thermal history, documented remedies | No process killing or cleanup without separate confirmation |
| App update session | Updates list, note summaries, app launch | Never installs without exact approval |
| Turn capture into work | OCR or transcript, redaction, Scratchpad, export | Never posts or shares itself |

### Not for agents

No all-apps Accessibility channel, unrestricted Terminal, or permission to
invoke any discovered menu item: content in a clipboard item, webpage or file
name would become an action. In mail, chat, calendar, browser forms, password
managers, finance and health, PowerTools AI may prepare a draft or open a deep
link, and does not act.

---

## 6. Integrations and the Claude Code connector

### Integration hierarchy

Use the least powerful integration that does the job:

1. Open, reveal and share through URLs, `NSWorkspace`, Finder and the share
   sheet.
2. App Intents and Shortcuts, publishing a small set of PowerTools AI's own
   safe actions.
3. Documented Apple Events for a named action, after macOS Automation consent.
4. A first-party adapter only for a high-demand app with a stable public API
   and a privacy review.
5. MCP as an advanced, explicit, per-server extension that never inherits
   another tool's configuration.

### PowerTools AI for other agents (M6)

Five to ten App Intents: run a Routine, open the Command Bar, capture with a
preset, start or stop Keep Awake, start a recording preset, open a Scratchpad,
invoke a quick toggle. A local MCP server follows the registry and confirmation
broker, with narrow tools:

```text
list_routines()                 run_routine(name, dry_run)
capture_screen(preset)          inspect_system_health(scope)
search_configured_files(query)  create_workspace_plan(goal)
```

It never exposes `run_shell`, `read_any_file`, `send_keypress`,
`click_screen_coordinate`, `set_any_preference` or bulk clipboard access.

### Claude Code connector (M6, experimental)

PowerTools AI can bridge to the person's own installed and signed-in Claude
Code, but cannot turn a Claude subscription into an API key: Anthropic treats
subscriptions and the API as separate products, and an `ANTHROPIC_API_KEY` in
the environment overrides subscription sign-in and bills API usage. Plan terms
for programmatic use have changed before; re-verify them when building.

- **Setup.** Detect `claude` on the PATH and read its version and status only.
  If missing, link to the official installer. If signed out, open a visible
  Terminal for Claude Code's own login. Never handle passwords, tokens or keys.
- **Runtime.** A child process in an explicitly chosen project directory, using
  documented structured output with a turn cap and time limit. Default to plan
  mode. Execution goes through Claude Code's own permission prompts; never pass
  `--dangerously-skip-permissions` or auto-approve tools.
- **Boundary.** A separately installed connector, versioned and flagged, that
  degrades to "Open Claude Code here" if third-party subscription use ends.

```text
ClaudeCodeProvider
 ├─ ClaudeExecutableLocator    // version and status only
 ├─ ClaudeSessionProcess       // JSONL over stdio, cancellation, timeout
 ├─ RepoScopeGrant             // bookmark to a chosen project
 ├─ ClaudePermissionBridge     // renders requests; never auto-approves
 └─ ClaudeRunStore             // opt-in local transcript reference
```

---

## 7. Evaluation, quality and release gates

| Gate | Requirement | From |
| --- | --- | --- |
| Contract | Every harness guarantee enforced by a check that fails with its guard removed | M1 |
| Availability | Each availability state and failure reproduced or covered | M2 |
| On-device boundary | On-device use makes no connection, confirmed with a network monitor | M2 |
| Cloud payload | Each cloud request equals its preview, confirmed with a local HTTPS proxy | M2 |
| Keys | No key in defaults, exports, logs or test output | M2 |
| Injection | Instructions inside clipboard text, notes, captures, file names and release notes never expand authority | M3 |
| Plan quality | 200+ intents with full schema, registry and approval compliance per provider; wrong-action rate and latency tracked | M4 |
| Failure paths | Every action tested with feature uninstalled, permission revoked, screen locked, offline, bad endpoint, cancelled | M4 |
| Accessibility | Streamed responses announced sensibly; plan review keyboard operable; no icon-only critical state | M2 |
| Resource budget | The budgets in section 9 hold on this M5 and on a base 8 GB Mac, measured on a release build | M2 |

Evaluation data is synthetic. Never commit captures, clipboard content, keys or
logs.

---

## 8. Privacy

`docs/PRIVACY.md` was rewritten on 2026-09-14 as the policy for the first public
release, covering on-device AI, cloud providers, local model servers and a
complete connection list. Before each release, confirm it matches behaviour.
Every new provider, host or outgoing data field updates it in the same pull
request. Its claim to list every connection must remain literally true.

---

## 9. Performance, resources and where AI runs

### Test conditions

Measured on 2026-09-14 on a MacBook (`Mac17,4`) with an Apple M5 (4 performance
and 6 efficiency cores) and 24 GB of memory, on macOS 26.5.2 and AC power, using
`top`, `footprint`, `ioreg` and two throwaway benchmark programs with synthetic
text.

- Background load was heavy during the model tests (Spotlight indexing peaked
  at 418% CPU, load average 12–37), so latencies are on the pessimistic side.
- The running app was the Developer build, which is unoptimised, and panel use
  was not controlled.
- **Not measured:** Neural Engine utilisation and energy (both need
  `powermetrics` with administrator rights), 8 GB Macs, macOS 14 and 15, and
  any real cloud provider.

### The app today

| State | CPU (one core) | Memory footprint | Wakeups |
| --- | --- | --- | --- |
| Idle, panel closed, 60 s | 0.22% average, 0.7% peak | 31 MB, peak 59 MB since launch | 5 per second |
| Idle after further use, 30 s, same process 15 minutes later | 0.95% average, 1.6% peak | 66 MB, peak 137 MB | 9 per second |
| Finder extension | 0.0% | 6.7 MB | — |
| On disk | Release app 50 MB, DMG 15 MB | | |

The app is light, but its idle cost roughly quadruples after activity and it
keeps the memory. That swing is larger than anything AI adds inside the app.
Before M2, profile the release build in controlled states — just launched, idle
with the panel closed, dashboard open, 60 s after closing — so AI changes are
measured against a stable baseline.

### Apple's on-device model

Two full runs; ranges cover both.

| Request | Input | Output | First words | Total |
| --- | --- | --- | --- | --- |
| Rewrite, first request of a process | 45 tokens | 46 tokens | 0.60 s | 1.09 s |
| Rewrite, warm | 45 | 48–110 | 0.26–0.31 s | 0.68–1.75 s |
| Rewrite after `prewarm()` | 45 | 46 | 0.32 s | 0.70 s |
| Summarise 685 words | 792 | 136–138 | 0.74–0.76 s | 2.39–2.43 s |
| Summarise 3,421 words | 3,936 | 124–138 | 3.65–3.66 s | 5.29–5.66 s |
| Structured plan from a 74-action list | 1,761 for the list alone | — | — | 1.89–2.07 s |
| 10 short requests back to back | — | — | — | 9.1–10.7 s, no failures |

What this shows:

- **It barely touches the app.** The calling process starts at 3 MB with
  `FoundationModels` linked, grows about 9 MB over 20+ requests, and uses 0.02–0.12 s
  of CPU per request.
- **The work happens in a system process.** `TGOnDeviceInferenceProviderService`
  (two processes) used 11–15% of one core while generating. Its memory went from
  157 MB before the run to about 550 MB at peak, and back to about 280 MB within
  two minutes. macOS loads and trims it, not PowerTools.
- **It runs on the Neural Engine.** GPU utilisation averaged 2% during generation
  against 9% at idle, which points to the Neural Engine, Apple's most
  power-efficient processor.
- **Generation speed:** 69–121 tokens per second.
- **Long prompts are slow to start.** Reading the prompt runs at about 1,000
  tokens per second, so a 3,936-token prompt waited 3.65 s for its first word.
- **The context window is 4,096 tokens**, read from `contextSize`. English text
  measured 1.15 tokens per word, so input tops out around 3,400 words once the
  answer's room is reserved.
- **Token counting needs macOS 26.4.** `tokenCount(for:)` is unavailable on
  26.0–26.3, so those versions must estimate from word count.
- **No throttling observed.** Ten back-to-back requests from a terminal process
  hit no rate limit. A menu bar app may be treated differently; that remains an
  M2 check.
- **Planning quality is a real risk.** Listing 74 actions used 43% of the
  context, and in both runs the model chose wrong actions (brightness instead of
  keep awake). One synthetic test, but a clear signal.

### Cloud providers

- **Cost inside the app is negligible.** A streaming HTTPS request (measured
  against the GitHub update check) took 0.43 s for the first connection and 0.04 s
  after, used 0.003–0.024 s of CPU and added about 4 MB.
- **Not measured:** the provider's own latency, speed and price. Those depend on
  the provider and model, and get tested with a real key in M2.

### How often AI runs

Model calls happen only when a person asks; nothing runs in the background.
These are design estimates, not usage data — the app collects none.

| Feature | Trigger | Calls per use | Uses per day, typical | Size, input / output tokens | On-device time per call |
| --- | --- | --- | --- | --- | --- |
| Command Bar text actions | Select text, pick an action | 1 | 10–30 | 50–800 / 50–300 | 0.7–2.5 s |
| Scratchpad and clipboard transforms | Pick an action | 1, or up to 4 chunks for long text | 2–10 | 200–3,900 / 100–300 | 1–6 s |
| Release-note summaries | Open App updates; cached per version | 1 per updated app | 0–15, in one batch | 300–1,500 / 80 | about 1.5 s each; 15 apps about 25 s in sequence |
| "Why is my Mac busy?" | Ask | 1 | 0–3 | 500–1,000 / 150 | about 2 s |
| Screenshot alt text and text cleanup | Ask on a capture | 1 | 0–10 | 200–1,500 / 60–200 | 1–3 s |
| AI onboarding (macOS 26) | First launch | 1 | once | about 300 plus shortlist / 200 | about 2 s |
| Ask mode plans (M4) | Describe a task | 1–3 | 2–10 | 600–2,500 / 100 | 2–3 s each |
| Semantic search index (M6) | New clipboard item or file | Embedding, not a language model | 50–500 | — | milliseconds with NaturalLanguage (to measure) |

A typical day is 30–70 calls, about 1–3 minutes of Neural Engine time; a heavy day
is about 150 calls and 5 minutes. PowerTools itself spends under 10 s of CPU on
that. The same typical day on a cloud provider is roughly 20,000 input and 8,000
output tokens; cost is those counts times the chosen provider's price.

### What changes, and how often it becomes a problem

| Risk | When it happens | How often | What we do |
| --- | --- | --- | --- |
| App CPU and memory grow | Always, but small: about +9 MB, no idle CPU | Every install | Create sessions lazily, release them after use, weak-link `FoundationModels` for macOS 14 |
| Streaming redraws the panel | 70–120 updates per second while text streams | Every streamed answer | Redraw at most 15 times a second; keep work off the main thread |
| Prompt exceeds 4,096 tokens | Input over about 3,400 words, or a plan that lists every action | Every long summary; every plan without a shortlist | Count tokens (26.4+) or estimate at 1.15 per word; chunk (at most 4 calls) or offer the cloud provider; shortlist at most 10 actions (about 250 tokens) |
| Long prompts feel slow | Over about 2,000 tokens: 2–4 s before the first word | Long inputs | Show progress, stream, allow cancel; never call the model per keystroke |
| First request is slower | First use after macOS unloads the model: 0.60 s versus 0.30 s to first words | First AI use of a session | `prewarm()` when an AI surface opens (measured 0.32 s) |
| System memory pressure | Inference service +100–400 MB while active | Only on smaller Macs already under pressure; unmeasured on 8 GB | Defer optional AI on memory-pressure warnings; test on a base 8 GB Mac |
| Background throttling | macOS may rate-limit a menu bar app | Unknown | Verify in M2; show the error and retry when the app is frontmost |
| One request at a time | A session answers one prompt at a time | Batches such as release notes | A single queue; cancel stale requests |
| Wrong plans | Large candidate lists | Likely frequent without a shortlist | Shortlist, `AIPlanValidator`, evaluation corpus; complex plans go to the cloud provider when configured |
| Heat and battery | Sustained agent loops or big batches | Rare with user-initiated calls | Capability lease caps turns; skip optional AI in Low Power Mode or at serious thermal pressure, which the app already reads |
| Cloud failures and cost | Offline, quota, provider latency, price | Whenever a cloud provider is used | Timeouts, clear errors, token limits, a token estimate before large requests, cached summaries |

### On the Mac or behind an API?

| | Apple on-device model | Cloud API with the person's key | Model bundled in the app | Local server (Ollama, LM Studio) |
| --- | --- | --- | --- | --- |
| **Pros** | Free; private; no download; +9 MB to the app; fast for short tasks (0.7–2.5 s); Neural Engine efficiency; works offline | Much stronger reasoning; long context; vision; works on macOS 14–15 and any Mac; no memory on the Mac | Works offline on every macOS version | Private; bigger models than Apple's; the person chooses and manages it |
| **Cons** | macOS 26 and an eligible Mac with Apple Intelligence on; 4,096-token context; small model, weak at large-list planning; guardrail refusals; language limits | Costs money per token; content leaves the Mac; needs a network; rate limits and outages; a key to manage | Gigabytes added to a 50 MB app; gigabytes of memory and GPU load inside PowerTools; a dependency and licences to maintain | The person must install and run it; heavy memory and energy while loaded; model quality varies |
| **Verdict** | Default where available | Opt-in, for what on-device cannot do | Not now (D10) | Opt-in for people who already run one |

**Recommendation:** no single choice. Route each task to the cheapest option that
can do it well, and ship no model of our own.

| Task | Default | Why |
| --- | --- | --- |
| Text actions under about 1,500 tokens | On device | 0.7–2.5 s, free, private |
| Classification, extraction, onboarding, "Why is my Mac busy?" | On device | Small inputs |
| Plans from a shortlist of at most 10 actions | On device, cloud if configured and the plan fails validation | Measured quality risk |
| Content over about 3,400 words | Chunk on device (at most 4 calls), or cloud with consent | Context limit |
| Vision beyond text recognition; long multi-step plans | Cloud if configured | Model capability |
| macOS 14–15, an ineligible Mac, or Apple Intelligence off | Cloud or local server if configured; otherwise the feature says what it needs | Availability |
| Search ranking, language detection, text recognition, embeddings | No language model: NaturalLanguage and Vision | Instant, no model call |

### Budgets

These become release gates from M2 (section 7).

- **Installed but unused:** no added idle CPU, at most +5 MB of app memory, no
  inference activity.
- **During a request:** app memory at most +15 MB, app CPU at most 0.2 s per
  request, at most 15 redraws per second, and the main thread never blocked.
- **Speed, on device and warm:** first words of a text action within 0.5 s;
  cancel within 100 ms.
- **Fan-out:** at most 4 model calls per user action unless the person approves
  more.
- **Deferral:** optional AI work waits in Low Power Mode, at serious thermal
  pressure, or on a memory-pressure warning.
- **Re-measure every milestone** on this M5 and on a base 8 GB Mac, with the
  benchmark kept as a script.

---

## Decision summary

PowerTools AI is a standalone, AI-enabled Mac utility. Finish its identity and
release readiness (M0) while making the agent contract enforceable (M1). Ship
text actions on device and through the person's own cloud provider as the first
release (M2). Widen to single-context features and on-device onboarding (M3),
then a supervised agent limited to reversible actions (M4). Translate (M5), then
reach into other apps and agents (M6). Every step is small, reviewed by the
maintainer and verified on a real Mac.

## Sources

SDK facts were read from the local macOS 26.5 SDK on 2026-09-14. The web sources
below were not re-fetched in that assessment; re-verify each where it becomes
load-bearing — Apple sources and provider terms before M2, Anthropic sources
before the M6 connector.

1. Apple. [Generating content and performing tasks with Foundation Models](https://developer.apple.com/documentation/foundationmodels/generating-content-and-performing-tasks-with-foundation-models).
2. Apple. [Meet the Foundation Models framework (WWDC25)](https://developer.apple.com/videos/play/wwdc2025/286/).
3. Apple. [Adding intelligent app features with generative models](https://developer.apple.com/documentation/foundationmodels/adding-intelligent-app-features-with-generative-models).
4. Apple. [App Intents](https://developer.apple.com/documentation/appintents).
5. Anthropic. [Why do I have to pay separately to use the Claude API and Console?](https://support.claude.com/en/articles/9876003-i-have-a-paid-claude-subscription-pro-max-team-or-enterprise-plans-why-do-i-have-to-pay-separately-to-use-the-claude-api-and-console).
6. Anthropic. [Use Claude Code with your Pro or Max plan](https://support.claude.com/en/articles/11145838-use-claude-code-with-your-pro-or-max-plan).
7. Anthropic. [Claude Code CLI reference](https://docs.anthropic.com/en/docs/claude-code/cli-usage).
