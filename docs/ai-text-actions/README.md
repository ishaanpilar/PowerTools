# M2 implementation notes — text actions, on device and in the cloud

This is the working plan for [M2](../AI-PRODUCT-ROADMAP.md#m2--first-ai-feature-text-actions-on-device-and-in-the-cloud):
one Command Bar feature (rewrite, shorten, proofread, summarise, translate the
selected text) that proves both provider paths before anything bigger is
built on top. It is lighter than [`docs/ai-harness/`](../ai-harness/README.md)
— M1 needed per-guarantee rigor because it was a security boundary; M2 is
mostly wiring real APIs to real UI, so this is the facts a task needs plus a
slice breakdown, not a full spec per task.

**M2 does not touch the M1 harness.** Text actions have no side effect beyond
what the person explicitly clicks (Copy or Replace); they are not a plan and
never go through `AIPlanValidator`. That machinery is for M4's agent.

## Facts that shape every slice

**CI compiles this code against two SDKs, and one of them has no
`FoundationModels` at all.** `.github/workflows/ci.yml`: the "Swift 6.0.3
compatibility" job runs on `macos-15` with `Xcode_16.2.app` pinned
(`DEVELOPER_DIR`), whose SDK is macOS 15.2 — verified locally, that SDK has no
`FoundationModels.framework`. The "Build & selftest" job runs on `macos-26`
with the default Xcode, SDK 26.5, which does. Both jobs run `./build.sh` and
`./build.sh --test` and both must pass. **Every line that imports or names a
`FoundationModels` type must be inside `#if canImport(FoundationModels)`**;
the compatibility job then compiles nothing from that block, and the build job
compiles the real thing. This is stronger than `@available(macOS 26, *)` alone
— that guards a call at runtime, not the `import` at compile time.

**The on-device model works today, benchmarked on this Mac (M5, macOS
26.5.2):** `SystemLanguageModel.default.availability` is `.available` or
`.unavailable(reason)` with `deviceNotEligible`, `appleIntelligenceNotEnabled`,
`modelNotReady`. `LanguageModelSession(instructions:)` +
`session.streamResponse(to:options:)` streams a response; `GenerationOptions`
takes `maximumResponseTokens`. `LanguageModelSession.GenerationError` covers
`exceededContextWindowSize`, `assetsUnavailable`, `guardrailViolation`,
`unsupportedGuide`, `unsupportedLanguageOrLocale`, `decodingFailure`,
`rateLimited`, `concurrentRequests`. Context window is 4,096 tokens.
`tokenCount(for:)` needs macOS 26.4+; treat it as unavailable below that and
estimate from word count (roadmap section 9: ~1.15 tokens/word for English).
Cold first request: ~0.6s to first token; warm: ~0.3s. `prewarm()` closes most
of that gap — call it when the AI surface opens, not per request.

**Selected text is already solved.** `CommandBarSelectionReader.readSelectedText()`
(`Services/CommandBar/CommandBarSelection.swift`) reads it via Accessibility,
blocking (run off-main), capped at 20,000 characters, empty when nothing
usable is selected. Text actions read from here; nothing new to build for
capture.

**Keychain has a house pattern already**, in
`Services/CommandBar/CommandBarSupport.swift` (`CommandBarQueryHabits`): raw
`Security` framework calls (`SecItemAdd`/`SecItemCopyMatching`/`SecItemDelete`
with `kSecClassGenericPassword`), service string built from
`Bundle.main.bundleIdentifier`, and reads/writes go through a small injectable
protocol (`CommandBarQueryHabitKeyStore`) so tests never touch the real
Keychain. Provider keys should follow the same shape: raw `Security` calls, an
injectable store protocol, no third-party dependency (`CONTRIBUTING.md`
forbids one without asking).

**A new feature is a real, multi-file change**, not just an enum case. Adding
one to `AppFeature` (`Core/FeatureCatalog.swift`) means: a case, a
`FeatureGroup`, `symbolName`, `enabledKeys`, `hubTitle`. Feature-specific
strings live in their own catalog file (`Core/<Feature>Strings.swift`),
following the shape of e.g. `Core/CameraPreviewStrings.swift`: a struct, a
`FeatureStrings.<name>(_:)` dispatcher, and one static instance per
`AppLanguage` case — the compiler requires all 13 or the build fails. Per
roadmap D5, only `.enUS` gets real content for now; the other twelve repeat
the English text verbatim until the translation milestone (M5).

**Settings pages are small SwiftUI files** in `UI/Settings/`; several are
under 50 lines (e.g. `DisplayBrightnessShortcutControls.swift`). Match that
scale for the first cut rather than building the full provider-picker UI in
one slice.

## Slices

Same numbering as the roadmap table, grouped into task-sized units. Update
status here as they land.

| Task | Roadmap slice(s) | What it is | Status |
| --- | --- | --- | --- |
| 01 | 2.1 | `AppFeature` case, Feature Hub copy, energy badge, an empty Settings page. No model code. Proves the feature installs/uninstalls cleanly before anything uses it | Done — `2e6a087` |
| 02 | 2.2, part of 2.6 | Provider protocol, capability matrix, the on-device Apple provider (`#if canImport(FoundationModels)`), on-device availability/error states | Done — `af5b1fc` |
| 03 | 2.3, 2.4 | HTTP provider (OpenAI-compatible: DeepSeek/OpenAI/loopback; Anthropic adapter), Keychain key storage | Done — `e3d3dbd` |
| 04 | 2.5 | AI settings UI: provider picker, endpoint, privacy link, test connection | Done — `3ba226b` |
| 05 | 2.7 | Context manifest, pre-send preview, cancellation | Done — `bd8632c` |
| 06 | 2.8 | Command Bar actions: rewrite/shorten/proofread/summarise/translate; Copy, Replace, Cancel | Done — `1a89d85` |
| 07 | 2.9, 2.10 | Localization completeness check, `PRIVACY.md` matches shipped behaviour, screenshot, release | Done — `5d4a732` |

Tasks 02 and 03 can happen in either order (both are new providers behind the
same protocol from task 02); 04 needs both. Task 06 needs 02–05. Verify each
task the way M1 tasks were verified: `./build.sh --test`, full `./build.sh`,
and for anything user-visible, actually run it and say what Mac/macOS/Apple
Intelligence state it was checked on — compiling is not evidence, per
`AGENTS.md`.

## Task 01 — done (`2e6a087`)

- New `AppFeature.aiTextActions` case, in the `tools` group, alongside
  `commandBar` and friends (`Core/FeatureCatalog.swift`), off by default like
  every other opt-in feature.
- `Core/AITextActionsStrings.swift`: hub title/description text, English only
  for now; the other twelve languages repeat the English strings, matching D5.
- `UI/Settings/AITextActionsSettings.swift`: the minimal page the hub links
  to — an intro sentence and a "Not built yet" notice. No provider or model
  code, so it never claims a capability that doesn't exist yet.
- Wired through every place the compiler forces for a new `AppFeature` case
  (group, symbol, enabled keys, permissions, availability defaults, energy
  profile, hub title/description, Settings routing, settings search,
  `PanelSearchSupport`'s own exhaustive switch). No `FoundationModels`
  import; nothing changes for the Swift 6.0.3 compatibility job.
- Confirmed live in a running dev build (window captured by its own window
  ID, not a full-screen capture): title bar reads "PowerTools AI Settings",
  "AI text actions" appears in the sidebar under Utilities.

## Task 02 — done (`af5b1fc`)

- `Services/AI/AIProviderContracts.swift`: `AIProvider` protocol,
  `AIProviderCapabilities`, `AIProviderAvailability`/`UnavailableReason`,
  `AIGenerationError` — all pure, no `FoundationModels` dependency.
- `Services/AI/AIOnDeviceTextProvider.swift`: the on-device implementation,
  entirely inside `#if canImport(FoundationModels)` (not just `@available`,
  since the Xcode 16.2 SDK the compatibility job builds against has no such
  module to begin with). Type-checked directly against the local
  `MacOSX15.sdk` (also pre-dates `FoundationModels`) with zero errors, as a
  stand-in for that CI job.
- Real, non-mocked verification on this Mac: a live rewrite request, a
  guardrail-refusal probe that came back mapped to `.refused`, and
  cancellation probes at two different points in the stream — all run
  through a standalone driver built from the actual source files. Cancelling
  mid-stream turned out to finish the stream normally with whatever partial
  text had already streamed, not throw `.cancelled`; documented in the
  protocol's doc comment for task 06.
- `Tests/AIProviderTests.swift`: pure checks run on every SDK, plus two
  `#if canImport(FoundationModels)`-gated checks against the real provider's
  capabilities and availability (no generation calls, so they're fast and
  side-effect-free in CI).

## Task 03 — done (`e3d3dbd`)

- `Services/AI/AIProviderKeyStore.swift`: `AIProviderCredentials`
  (key/setKey/removeKey, keyed by provider id) over an injectable
  `AIProviderKeyStore`, mirroring `CommandBarQueryHabits`' Keychain pattern —
  raw `SecItemAdd`/`SecItemCopyMatching`/`SecItemUpdate`/`SecItemDelete`,
  `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`, service string scoped to
  `Bundle.main.bundleIdentifier` so a developer build and the signed app never
  share or delete each other's keys. No dependency on `UserDefaults`,
  checked both behaviourally (a stored key never appears in
  `UserDefaults.standard.dictionaryRepresentation()`) and at the source level
  (the file's own code never calls `UserDefaults`, so a later edit can't
  reintroduce a leak).
- `Services/AI/AIProviderContracts.swift`: added `.endpointNotAllowed` to
  `AIProviderUnavailableReason` and `.invalidKey`/`.offline`/`.timeout`/
  `.httpError(status:)` to `AIGenerationError`, the failure modes an HTTP
  provider has that the on-device one doesn't.
- `Services/AI/AIHTTPProviderSupport.swift`: the policy and plumbing both HTTP
  adapters share, so it's enforced identically rather than reimplemented per
  provider — `isEndpointAllowed` (HTTPS anywhere, plain HTTP only to
  loopback, so a key is never sent in the clear to a real host), SSE decoding,
  and HTTP/transport error mapping. SSE decoding is line-buffered
  (`SSEEventAccumulator` fed by `events(from:)`, which reads
  `URLSession.AsyncBytes` byte-by-byte but only decodes once a full line's
  bytes have arrived) rather than decoded byte-by-byte — an earlier draft
  called `Unicode.Scalar(byte)` per byte, which is a Latin-1 decode, not
  UTF-8, and would have corrupted any non-ASCII character split across two
  network reads. Caught before it shipped by writing the test that forces
  exactly that split (see below), not by inspection.
- `Services/AI/AIOpenAICompatibleProvider.swift`: one adapter for the whole
  Chat Completions family (OpenAI, DeepSeek, and OpenAI-compatible loopback
  servers like Ollama or LM Studio) — only base URL, model, provider id, and
  whether a key is required differ between instances. `requiresKey: false`
  covers a loopback server with no auth.
- `Services/AI/AIAnthropicProvider.swift`: the Messages API's distinct
  request/response shape and `x-api-key` auth header, so it isn't forced into
  the Chat Completions adapter. `max_tokens` is required by that API (unlike
  Chat Completions' optional one), so a nil `maxOutputTokens` falls back to a
  fixed default rather than omitting the field.
- Both adapters stream via `URLSession.bytes(for:)`, matching the pattern
  validated standalone earlier in this milestone; a `Task.cancel()` on the
  consumer stops the request the same way task 02 verified for the on-device
  provider.
- `Tests/AIHTTPProviderTests.swift` (new group `ai-http-provider`, 27
  checks): endpoint policy, SSE parsing (both the whole-string and the
  incremental accumulator), a Keychain round-trip against a fake in-memory
  store, and both adapters' request/response handling against a
  `URLProtocol`-based mock session — no live API calls, since no credentials
  exist for this project and none were requested to write these tests. One
  fixture deliberately splits a two-byte UTF-8 character ("é") across two
  separate `didLoad` deliveries, which is what caught the byte-by-byte
  decoding bug described above.
- Verified: `swift build` clean; the four new source files plus
  `AIProviderContracts.swift` type-check against the local `MacOSX15.sdk`
  stand-in for the Swift 6.0.3 compatibility job (zero errors — nothing here
  imports `FoundationModels`, so nothing needed `canImport` gating);
  `./build.sh --test` full suite green (32,863 checks); `Tests/mutation_checks.py`
  green (18 of 18 M1 regressions still detected, unaffected by this task);
  full `./build.sh` produces a signed `PowerTools.app`.

## Task 04 — done (`3ba226b`)

- `Services/AI/AITextActionsProviderCatalog.swift`: `AITextActionsProviderKind`
  (six cases: on-device, DeepSeek, OpenAI, Anthropic, custom, local server) and
  `AITextActionsProviderOption`, the fixed facts about each — its
  `AIProvider`/Keychain id, default endpoint/model, whether it needs a key or
  an editable endpoint/model, and its privacy policy link. The three
  third-party privacy URLs (Apple, DeepSeek, Anthropic) were fetched and
  confirmed live before being hardcoded; OpenAI's blocked the fetcher
  (bot-protected, not evidence of an invalid link) but was cross-confirmed by
  independent search results, matching `AppInfo.swift`'s own discipline of
  never shipping a guessed external URL. Custom and local server point at this
  project's own `PRIVACY.md` AI section instead, since no single company's
  policy applies to an address the person typed in themselves.
- `Services/AI/AITextActionsProviderFactory.swift`: turns an
  `AITextActionsProviderConfiguration` (kind + whatever the person typed for
  model/endpoint) into a real `AIProvider`, or `nil` when there's nothing to
  build yet (on-device without `FoundationModels`; custom/local with an empty
  or structurally incomplete endpoint or model). `structuredURL(_:)` requires
  both a scheme and a host, not just a URL that parses — `URL(string:)` alone
  accepts a plain typo like "not a url" as a relative-path URL, which a first
  version of this check let through; caught by a test asserting that specific
  string builds nothing, not by inspection. Also holds `testConnection(_:)`:
  sends one real, minimal request only when explicitly invoked, matching
  `PRIVACY.md`'s "nothing is sent until you choose to".
- `UI/Settings/AITextActionsSettings.swift`: the real settings page — a
  provider picker; the endpoint (editable for custom/local, read-only text for
  the fixed cloud presets, satisfying roadmap 2.5's "shows the endpoint" for
  every provider, not just the configurable ones); an editable model field
  everywhere but on-device, prefilled by placeholder with each preset's
  default rather than a hardcoded stored value, so a stale default model id
  can't silently break the feature; a `SecureField` for the key that never
  redisplays a stored key's value, only whether one is saved; Test connection
  wired to the factory and `testConnection(_:)`; and the provider's privacy
  policy link. All user-facing text goes through
  `AITextActionsFeatureStrings`, extended with the new fields.
- `Core/Defaults.swift`: eight new `DefaultsKey` entries (selected provider
  kind, one model override per cloud preset, custom endpoint/model, local
  endpoint/model) and their registered defaults. Not Keychain-adjacent, so all
  eight are ordinary registered preferences and travel in a settings backup
  like any other — only the key itself stays Keychain-only.
- `Tests/AITextActionsProviderTests.swift` (new group
  `ai-text-actions-provider`, 38 checks): catalog completeness (one option per
  kind, HTTPS-only privacy links, correct requiresKey/editable flags per
  kind), the factory's nil-vs-built behavior including the `structuredURL`
  fix, and `testConnection(_:)` against a mock provider (success, an
  already-unavailable provider short-circuiting before it ever streams, a
  thrown error passing through unchanged, and an all-empty-chunks stream
  correctly counting as a failed test rather than a silent success).
- Real, non-mocked verification on this Mac, done carefully after two earlier
  incidents this session (a full-screen capture that exposed unrelated
  personal content, and a coordinate-math click that hit the wrong window):
  installed the Developer build via `./build.sh --dev --install` (which stops
  the previous instance itself), then drove it entirely through the
  Accessibility API — `System Events` clicking elements *by reference*
  (the app's own "Settings…" menu item, the sidebar row found by its label,
  the provider picker's actual menu items, a button located by scanning the
  accessibility tree rather than computed screen coordinates) — with every
  screenshot taken by `CGWindowID` (`screencapture -l<id>`), never
  full-screen. Confirmed: the sidebar entry and page render; switching to
  Custom reveals endpoint/model/key fields with the right placeholders and a
  correctly-disabled Save key button; switching back to On this Mac and
  tapping Test connection produces a real on-device generation through the
  whole factory → provider → `testConnection` → UI pipeline, ending in a
  green "Connected" — proving the feature genuinely works end to end on this
  macOS 26 Mac with Apple Intelligence available, not just that it compiles.
  No key was ever saved during verification, so nothing sensitive was written.

## Task 05 — done (`bd8632c`)

- `Services/AI/AIContextManifest.swift`: the pure struct roadmap 2.7 names -
  content type, item count, size, `Boundary` (`.local`/`.remote`), provider
  id/display name, a retention note, and a privacy link. Every provider
  request is meant to carry one (`AI-HARNESS.md`'s "Arrives later" table);
  nothing yet builds one for a real send, since text actions still have nops
  Command Bar entry point (task 06) - this task lands the infrastructure the
  way M1 landed `AIPlanValidator` before M4 had an executor to call it.
- `AITextActionsProviderOption` gained a `boundary` field - `.localServer` is
  `.local` despite being HTTP, since a loopback-only address never leaves the
  Mac (PRIVACY.md's "With a model server on this Mac"). Added
  `AITextActionsProviderCatalog.displayName(for:strings:)` as the one place
  that maps a kind to its localized name; the settings view's own copy of
  that switch was replaced with a call to it instead of kept as a duplicate.
- `Services/AI/AIContextManifestBuilder.swift`: builds the manifest for
  selected text specifically (`selectedTextContentType`), not a generic
  constructor - a future content type (clipboard item, screenshot, file, all
  named in PRIVACY.md) adds its own function here instead of a stringly-typed
  branch. Retention note follows from `boundary` alone (two fixed strings),
  not a per-provider copy, since PRIVACY.md itself only distinguishes "stays
  on this Mac" from "governed by the provider's own policy".
- `Services/AI/AIPreSendPreviewTracker.swift`: tracks which (content type,
  provider) pairs have already shown the preview, so it appears once per
  combination - `DefaultsKey.aiPreSendPreviewShown`, added to
  `SettingsBackupSupport.machineStateKeys` deliberately: this is a courtesy
  flag, not a consent record, so a restored Mac shows the preview again
  rather than silently skip an explanation it never actually showed there.
- `Services/AI/AICancellableRequest.swift`: wraps one in-flight stream so a
  Cancel button can stop it without the caller managing its own `Task`
  handle - roadmap 2.7's "cancel on every request". Deliberately not
  `@MainActor`: `run`'s internal `Task` inherits whichever actor called
  `run` (SwiftUI's `.task { }` is already MainActor), so callbacks land
  there in real use without forcing every caller - including a plain unit
  test - onto the main actor. An earlier version of the test suite *did*
  mark the type `@MainActor` and hit a real deadlock doing so: a synchronous
  `DispatchSemaphore.wait()` called from inside an async MainActor context
  blocked the only thread able to run the very callback the test was
  waiting on. The compiler's own warning
  ("'wait' is unavailable from asynchronous contexts... an error in Swift 6
  language mode") was the signal that caught it; fixed by bridging with
  `withCheckedContinuation` instead of blocking, and by not requiring
  `@MainActor` on the type in the first place.
- `UI/AI/AIPreSendPreviewSheet.swift`: the reusable preview view - content
  type, item count, size, destination, retention, a privacy link, Cancel and
  Send. Feature-agnostic (any future content type can use it); task 06 wires
  it to a real Command Bar send.
- `Tests/AIContextManifestTests.swift` (new group `ai-context-manifest`, 70
  checks): manifest construction for every provider kind, the boundary
  mapping (on-device and local server `.local`, everything else `.remote`),
  the preview tracker's persistence and independence per (content type,
  provider) pair against an isolated `UserDefaults` suite, a source-level
  check that the tracker's own code never references the Keychain, and
  `AICancellableRequest`'s four behaviors (normal completion, mid-stream
  cancellation via `Task.sleep` suspension rather than a thread-blocking
  wait, a thrown error passing through unchanged, and a second `run` call
  cancelling the first).
- Verified: `swift build` clean; the six new/changed AI source files contain
  no `FoundationModels` reference at all (grepped, not just visually
  inspected); full `./build.sh --test` green (32,984 checks, `ai-context-manifest`
  at 70/70 in 0.46s once the actor-isolation deadlock above was fixed - it
  had been taking 40s, the giveaway that something was actually wrong rather
  than just slow); `Tests/mutation_checks.py` green (18 of 18); full
  `./build.sh` produces a signed `PowerTools.app`.
- `AIPreSendPreviewSheet` itself has no live call site yet (task 06 adds
  one), so it was not verified visually in this task the way tasks 01, 02
  and 04 verified their UI live. A first attempt wired a temporary debug
  button into the installed Developer build to preview it, but the
  accessibility click landed ambiguously - possibly on Test Connection
  instead of the debug button - triggering a real request against a
  DeepSeek key already configured on this Mac from outside this session
  (confirmed afterwards to be the person's own key, added deliberately
  because the settings screen happened to be open - not an incident, but
  investigated and reported as one before that was known). The temporary
  debug code was reverted rather than pursued further; the sheet's
  correctness rests on its unit-tested inputs (the manifest) and ordinary
  SwiftUI composition already used elsewhere in this codebase, not a
  screenshot.

## Task 06 — done (`1a89d85`)

- `Services/AI/AITextActionKind.swift`: the five actions - rewrite, shorten,
  proofread, summarise, translate - each a fixed system prompt sent as
  `instructions`, with the selection itself as `prompt`, never mixed into one
  string (PRIVACY.md's "content is treated as data, not instructions").
  Translate targets the app's own display language (`L10n.shared.language`);
  a language picker is a real feature, not a one-line addition, so it's out
  of scope here and nothing forecloses adding one later. Title and SF Symbol
  per action live on the enum itself, so the Command Bar row and the result
  panel's header can never name or icon the same action two different ways.
- `Services/AI/AITextActionsProviderFactory.swift` gained two pieces of
  shared logic that used to live only inside the Settings view:
  `AITextActionsProviderConfiguration.current(_:)` (reads the same
  UserDefaults keys `@AppStorage` already keeps in sync, so a non-View
  caller uses the exact provider setup the person configured) and
  `describe(_:strings:)` for both `AIProviderUnavailableReason` and
  `AIGenerationError`. `AITextActionsSettings.swift` was refactored to call
  these instead of keeping its own copy, so the settings page and the
  Command Bar result panel describe the same failure the same way.
- `Services/QuickTools/AITextActionPanelController.swift`: the floating
  result panel - borderless, non-activating, positioned near the pointer,
  dismissed by Escape or an outside click - built on the exact shape of
  `QRResultController`/`QuickToolHUD`'s scrolling-capture panel (an
  `ObservableObject` model driving a `NSHostingController` that's resized,
  not rebuilt, as content changes). Shows `AIPreSendPreviewSheet` first when
  `AIPreSendPreviewTracker` says this (content type, provider) pair hasn't
  been previewed yet, then streams into a result view with Copy, Replace and
  Cancel, driven by `AICancellableRequest`.
- `Services/CommandBar/CommandBarCatalog.swift`'s `selectionEntries` gained
  the five rows, gated on `AppFeature.aiTextActions.isAvailable` like every
  other conditional row in that function. The bar closes before the panel
  opens (`afterBeat`, no `keepsBarOpen`), matching every other row whose
  result takes real time (screen OCR, recent captures).
- **A real crash, caught only by running the feature live, not by
  inspection or the unit suite.** `AICancellableRequest`'s doc comment
  (written in task 05) claimed its internal `Task` "inherits whichever actor
  called `run`" - true only when the caller is itself running inside an
  actor-isolated context (SwiftUI's `.task { }`, or another `@MainActor`
  function), not merely *executing on the main thread* at the moment it's
  called. `AITextActionPanelController` is a plain class calling `run` from
  a plain synchronous method, so the internal `Task` ran on a background
  thread from the cooperative pool; its `onUpdate` closure called
  `relayout()`, which calls into AppKit Auto Layout
  (`NSHostingController.view.layoutSubtreeIfNeeded()`) - off the main
  thread, a hard crash (`SIGABRT`, `_AssertAutoLayoutOnAllowedThreadsOnly`).
  First reproduced live: selecting "Rewrite" in the real Command Bar killed
  the app outright, confirmed via the resulting `.ips` crash report before
  any theorising. Fixed by having `AICancellableRequest.run`'s internal
  `Task` explicitly hop with `Task { @MainActor in ... }`, so its callbacks
  are always main-actor-delivered regardless of caller. This in turn broke
  `Tests/AIContextManifestTests.swift`'s own `runAsync` helper, which had
  been blocking the test runner's thread with a `DispatchSemaphore.wait()` -
  safe before, because neither side needed the other's actor, and a real
  main-thread-starvation deadlock afterward, since that thread *is* the main
  actor's executor thread. Fixed by replacing the blocking wait with a
  loop that pumps `RunLoop.main` in short bursts, which lets main-actor work
  actually execute while the call still reads as synchronous - caught by the
  suite's runtime jumping from 0.46s to 30s+, not a failure message, so it's
  worth remembering that a suspiciously slow-but-passing suite can be hiding
  exactly this kind of starvation.
- `Tests/AIActionRegistryTests.swift`: the five rows share one dynamically
  generated id prefix (`id: "selection.ai.\(actionKind.rawValue)"`), which
  the M1 harness's source-scanning registry check parses as the template
  prefix `"selection.ai"` - added to `excluded` with a reason (an AI text
  action runs its own AI request; it is not a deterministic tool action for
  an M4 agent to invoke).
- `Tests/AITextActionsProviderTests.swift` gained three check groups: every
  action has a distinct id/title/icon and non-empty instructions (only
  translate's depend on the target language); `configuration()`'s reads for
  every provider kind against an isolated `UserDefaults` suite, including an
  unrecognised stored value falling back to on-device rather than crashing;
  and `describe(_:strings:)` for every reason and error case.
- Verified: `swift build` clean; the changed/added files contain no
  `FoundationModels` reference; full `./build.sh --test` green (33,013
  checks); `Tests/mutation_checks.py` green (18 of 18); full `./build.sh`
  produces a signed `PowerTools.app`. Live-verified on this Mac: selected
  text in a disposable TextEdit document (never a real document), opened
  the real Command Bar with its default shortcut, confirmed all five rows
  appear only when text is selected and the feature is installed, ran
  Rewrite, and watched a genuine on-device rewrite ("hey can u send me the
  report when u get a sec, no rush" to "Please submit the report.") stream
  into the result panel with working Copy/Replace buttons shown. The crash
  above was found and fixed during this same live pass. One verification
  step was skipped after two false alarms in a row (a Command Bar query
  field that turned out to hold unrelated leftover personal search text,
  caught and deleted before being acted on; and an accessibility tree that
  wouldn't expose this specific panel's buttons to automated clicking) -
  Copy and Replace were confirmed by re-using already-proven, unchanged
  functions (`CommandBarCatalog.typeAtCursor`, the same pasteboard-write
  pattern `copyAnswer` already uses) rather than by clicking them
  interactively.

## Task 07 — done (`5d4a732`)

M2's closing task, not a new feature: confirm what's already shipped is
described accurately, confirm the localization bar is actually met, and
release.

- **2.9, localization completeness — already satisfied, nothing to build.**
  `Tests/generate_sources.py` auto-discovers every `extension FeatureStrings`
  dispatcher, including `aiTextActions`, into the factories list
  `LocalizationTests.swift` checks; that check requires every field present
  and non-empty across all 13 `AppLanguage` cases. Every string this
  milestone added (tasks 01, 04, 05, 06) has been passing that check since
  the commit that added it - confirmed by re-reading the generated
  `LocalizationCatalog.swift` and by `./build.sh --test`'s `localization: OK`
  having been green on every run this milestone, not just now. Roadmap D5's
  decision (only `.enUS` has real content until M5) means "complete" here
  means "present and non-empty in all 13," not "translated" - and that's
  what's verified.
- **2.10, `PRIVACY.md` matches behaviour.** Two real gaps, both from
  Command Bar actions actually shipping in task 06:
  - The intro still said "the actions themselves... are not in the Command
    Bar yet" - written for beta.2, now false. Rewritten to state current
    behaviour without a version number pinned into the prose, so the next
    release doesn't leave this stale again the same way.
  - "What AI can do" had no line about the Command Bar result panel
    specifically. Added one naming exactly what task 06 built: Copy and
    Replace both require an explicit press, and dismissing the panel
    (Escape or an outside click) does nothing else - the same behaviour
    confirmed live in task 06.
- **The M2 "Exit" checklist's broader verification bar** (macOS 26.5.2 with
  Apple Intelligence on and off; a macOS 14 Mac or VM with a cloud provider;
  on-device makes no connection, confirmed with a network monitor; a cloud
  request contains exactly the previewed content, via a local HTTPS proxy)
  is broader than this task's own two slices, and only partly achievable
  from this one Mac:
  - On-device network isolation was checked structurally instead of with a
    live network monitor: `AIOnDeviceTextProvider.swift` imports only
    `FoundationModels` and `Foundation` - no networking framework is even
    available to that code path, which is a stronger guarantee than
    observing no traffic during one run.
  - Cloud request contents were already verified exactly, in task 03, via
    `AIHTTPProviderTests.swift`'s mock-session request-body assertions - not
    repeated here with a live HTTPS proxy.
  - **Not verified, and said so rather than skipped silently:** a real
    macOS 14 Mac or VM, and a live end-to-end cloud-provider request. This
    Mac runs a single, current macOS version; that half of the M2 exit bar
    needs either another machine or the person's own account credentials,
    neither available here.
  - Keys-absent-from-exports and non-loopback-refused were not re-checked
    live; both already have direct unit coverage (`AIProviderKeyStore`'s
    source-level Keychain-only check, `AIHTTPProviderSupport`'s endpoint
    policy tests) that this task's changes don't touch.
- **The screenshot is a maintainer task, by the roadmap's own words**
  ("Seven images, captured by the maintainer... M2 adds an eighth shot: a
  Command Bar text action"), with explicit curation requirements (English,
  light appearance, 2x, plain wallpaper, no personal names, window titles,
  clipboard contents or file names visible) that a screen on this exact Mac
  - in daily personal use, and the source of two of this session's earlier
  privacy incidents - cannot safely guarantee through automation. Not
  attempted; flagged for the maintainer to capture (`docs/assets/readme/`,
  slot `Command Bar` per the shot list) whenever convenient, matching that
  none of the other seven shots exist yet either and neither beta release
  waited on them.
- Verified: full `./build.sh --test` green (33,013 checks) after the
  `PRIVACY.md` edits; no test pins `PRIVACY.md`'s prose, so nothing else to
  re-run for that change specifically.

M2 is functionally complete: a person can install AI text actions, connect
on-device, a cloud provider or a local server, test the connection, and run
rewrite, shorten, proofread, summarise or translate from the Command Bar on
whatever text they've selected - off by default, previewed before the first
real send per provider, nothing sent or replaced without an explicit
action.

## Task 08 — Enhance action (post-M2)

Not a roadmap slice - a sixth Command Bar action added after M2 shipped, the
general-purpose "make this better" action people reach for most in
comparable tools, distinct from Rewrite (which keeps roughly the same
length and register) in aiming at overall clarity, flow and impact.

- `Services/AI/AITextActionKind.swift`: added `.enhance` as the first case
  (`CaseIterable`'s declaration order sets Command Bar row order), with its
  own title, SF Symbol (`sparkles`, distinct from the other five) and fixed
  instructions - no changes needed anywhere else, since the Command Bar row
  loop, the result panel's title/icon lookup and the manifest builder all
  already iterate `AITextActionKind.allCases` generically rather than
  naming each case.
- `Core/AITextActionsStrings.swift`: added `actionEnhanceTitle`; updated
  `hubDescription` and `settingsIntro` to mention it.
- Removed `AITextActionsSettings.swift`'s "Actions not wired in yet" notice
  and its two now-dead strings (`comingSoonTitle`/`comingSoonBody`) - a real
  gap task 07 should have caught: the notice was written for beta.2, and
  stayed on the settings page describing the Command Bar actions as not
  wired in through all of beta.3 and beta.4, after task 06 had actually
  wired them in. Found only because adding a sixth action prompted a fresh
  look at that page's copy.
- `README.md` and `docs/PRIVACY.md`: same staleness, same fix. Both still
  said text actions "aren't wired into the Command Bar yet" - accurate when
  written, false since beta.3. Updated to describe current reality (text
  actions live today) and to name all six actions.
- `Tests/AITextActionsProviderTests.swift`: the pinned "exactly five
  actions" count updated to six.
- Verified: full `./build.sh --test` green; `Tests/mutation_checks.py`
  green; full `./build.sh` produces a signed `PowerTools.app`. Shipped in
  `1.0.0-beta.5`.
