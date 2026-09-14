# AI harness contract

This is the runtime contract for PowerTools AI features. It exists so
providers, prompts and UI can evolve without widening what an agent can do.
Read it with [the product roadmap](AI-PRODUCT-ROADMAP.md) and
[AGENTS.md](../AGENTS.md).

## Loop

PowerTools AI agents follow a bounded loop:

`observe registered context → make typed plan → validate locally → obtain
approval → execute registered action → verify → report`

The model is never the authority for action identity, permission, scope, or
completion. It can choose among registered capabilities and explain its choice.
The app validates the model output before it reaches an executor.

## Action classes

| Risk | Example | Approval |
| --- | --- | --- |
| `readOnly` | Inspect metric snapshot; search a configured folder | None after context grant |
| `reversible` | Arrange named windows; start a Keep Awake timer | Each action in a reviewed plan |
| `destructive` | Empty Trash; remove a Cleaner candidate | Target-specific confirmation immediately before run |
| `external` | Create screenshot link; open an app updater | Destination-specific confirmation |
| `privileged` | An Automation action or administrator-backed operation | Target-specific confirmation plus existing macOS authorization |

Only a registered action can run. The registry supplies its feature dependency,
required macOS permission, risk and executor; an LLM-provided string is never
passed to a shell, Apple Event, URL opener, file operation, or setting writer.

## Context and memory

Every request has a context manifest: source type, item count, size, provider,
local/cloud boundary, and retention behavior. Cloud requests show this manifest
before the first send for a source type. The model only receives the minimum
selected context, and persistent memory is opt-in, inspectable and deletable.

Do not feed a provider unrestricted screen pixels, clipboard history, Finder
contents, browser contents, microphone audio, terminal history, or a user's
home directory. Content from those sources can contain prompt injection; it
must not alter tool availability or approval requirements.

## Capability lease

Each run has a finite tool set, explicit resource scope, turn cap and deadline.
It ends when the request finishes, is cancelled, times out, or the app quits.
Background work needs a separately saved Routine with its own bounded policy.
Agents may not self-expand their tool list, scope, time budget, provider or
permission grants.

## Provider policy

Apple Foundation Models are preferred for supported on-device requests
(macOS 26 and later). Cloud providers are available from macOS 14 and require a
named provider, a Keychain-backed key supplied by the person, a visible payload
preview and a privacy-policy link. Local model servers must be loopback-only.
Claude Code is an external local connector: it owns its own authentication and
its own project-tool approvals. PowerTools AI neither extracts its credentials
nor passes `--dangerously-skip-permissions`.

## Evaluation contract

`Tests/AIHarnessTests.swift` holds deterministic safety invariants that must
pass without contacting any model. Add a fixture whenever a new action class,
provider capability, approval path or context source is introduced. Model
quality evaluations belong in a separate synthetic corpus; do not commit user
captures, clipboard content, API keys, or production logs.

## Required action receipt

After a run, show a local receipt with the provider, context manifest summary,
approved actions, actions actually executed, result, skipped/failed steps and
undo/recovery path where applicable. Persist a receipt only when the user opts
in; it must never contain credentials or raw sensitive context by default.
