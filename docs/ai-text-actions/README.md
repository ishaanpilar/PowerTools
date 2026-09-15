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
| 05 | 2.7 | Context manifest, pre-send preview, cancellation | Not started |
| 06 | 2.8 | Command Bar actions: rewrite/shorten/proofread/summarise/translate; Copy, Replace, Cancel | Not started |
| 07 | 2.9, 2.10 | Localization completeness check, `PRIVACY.md` matches shipped behaviour, screenshot, release | Not started |

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
