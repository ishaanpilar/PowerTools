# Contributing to PowerTools AI

PowerTools AI is a local-first macOS menu bar app that brings everyday Mac
utilities together with AI that runs on your Mac, or through a provider you
choose. This guide covers building it, what belongs in it, and how changes are
reviewed.

Working with a coding agent? Point it at [AGENTS.md](AGENTS.md) and read it
yourself. It holds the rules you both work under.

## Licence

PowerTools AI is licensed under GPL-3.0-or-later, and contributions are
accepted under the same licence.

Keep every existing copyright and licence notice in a file intact; the licence
requires it. New files begin with:

```swift
// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 PowerTools AI contributors
```

## Requirements

| To | You need |
| --- | --- |
| Run the app | Apple Silicon Mac, macOS 14 or later |
| Build | Xcode or the Command Line Tools with the macOS 26 SDK |
| Test on-device AI | macOS 26, an eligible Mac, Apple Intelligence switched on |
| Test cloud AI | Your own provider API key, never committed |

The build is a plain `swiftc` invocation in `build.sh`, with no Xcode project
and no external dependencies. `Package.swift` exists so editors can index the
code and `swift build` can type-check it quickly.

## Build and test

```sh
git clone <repository-url>
cd <repository-folder>
./build.sh                       # build and assemble the app
./build/PowerTools --selftest    # health check
./build.sh --test                # unit and AI harness tests
./build.sh --install             # install into /Applications and launch
```

The public name is PowerTools AI; the code, binary and bundle identifiers still
use `PowerTools`. Leave those identifiers alone — renaming them discards stored
settings and permission grants.

Two things catch people out:

- `./build.sh --test` builds a hand-written list of files, and most of
  `Sources/PowerTools/UI/` is not on it. When you change UI, run plain
  `./build.sh` too.
- `swift build` answers whether the Swift compiles, and nothing about bundles,
  entitlements, signing or permissions.

Build or permission trouble? See [troubleshooting](docs/TROUBLESHOOTING.md).

### Stable signing

`build.sh` signs ad hoc by default, and that signature changes on every build.
macOS ties Accessibility and Screen Recording grants to the signature, so each
rebuild silently orphans them: System Settings still shows the app as allowed,
but macOS no longer trusts it.

Builds that install (`--dev` or `--install`) create a free, self-signed
`PowerTools Signing` identity in a dedicated keychain when none exists. For
builds you do not install, run once:

```sh
./Tools/setup-signing.sh
```

Local builds then keep a constant identity and their permissions. If an earlier
ad hoc build was granted a permission, clear it once
(`tccutil reset Accessibility com.powertools.utils.dev`) and grant it again.

## Project layout

| Folder | Role |
| --- | --- |
| `Sources/PowerTools/App` | App lifecycle and the menu bar item |
| `Sources/PowerTools/Core` | Strings, feature and permission catalog, defaults keys |
| `Sources/PowerTools/Services` | All behaviour |
| `Sources/PowerTools/Services/AI` | AI contracts, providers and planning |
| `Sources/PowerTools/UI` | SwiftUI views only |
| `Sources/PowerTools/Support` | `--selftest` and `--sensors` diagnostics |
| `Tests` | Behaviour, source-shape and AI harness tests |
| `Tools` | Signing, packaging, notarisation and brand asset generators |
| `docs` | Privacy, permissions, troubleshooting, AI harness and roadmap |

Conventions:

- UI observes services, and services never import SwiftUI.
- Shared services are exposed as `Type.shared` and publish with Combine
  `ObservableObject`. The project does not use Observation macros.
- Comments explain why, and are rare.
- No new dependencies without agreeing it in an issue first.

## What belongs in PowerTools AI

A good addition makes a task people already do on a Mac faster, clearer or
safer, and leaves them in control.

AI belongs here when:

- it works on content the person chose;
- its result is visible before anything changes;
- every action it takes runs through a registered, validated action (see
  [the AI harness](docs/AI-HARNESS.md));
- it runs on device where the Mac supports it, and through a provider the person
  chose where it does not;
- the feature it improves still works without it.

It does not belong here if it:

- watches the screen, keyboard, microphone, camera or clipboard in the
  background;
- deletes, moves, installs, shares, sends or changes settings without a specific
  approval;
- needs an account, a server run by the project, telemetry or collected prompts;
- scores productivity, detects emotion or monitors employees;
- is a chat window disconnected from the app's own features;
- gives a model unrestricted shell, AppleScript or Accessibility access.

Before proposing a feature, answer four questions in the issue:

1. **What is it built on, and will that still be there?** Public frameworks and
   documented provider APIs last; private APIs and undocumented behaviour are
   borrowed. Provider pricing and terms change, so plan for that.
2. **What does it expose people to?** Data leaving the Mac, charges on their API
   bill, permissions they must grant.
3. **What does it drag in?** A dependency, a tool the person must install, a
   service someone has to run.
4. **How many people will use it, against the surface it adds?** Every feature
   adds settings, strings, permissions and provider cases forever.

Anything bigger than a fix starts as an issue. Settling direction there costs
far less than a rejected branch.

## Adding an AI feature

| Capability | Minimum macOS |
| --- | --- |
| App and every utility | 14 |
| Cloud AI providers | 14 |
| On-device AI | 26 |
| AI onboarding | 26 |

An AI pull request is ready when:

1. Actions come only from the registry derived from `CommandBarCatalog`, and
   every plan passes `AIPlanValidator`.
2. `Tests/AIHarnessTests.swift` gains a check for each new action class, argument
   kind, approval path, provider capability or context source.
3. Every availability state has a message: macOS too old, Mac not eligible,
   Apple Intelligence off, model not ready, no provider chosen, invalid key,
   offline.
4. Every failure is visible — context too long, refusal, rate limit, unsupported
   language, cancellation, invalid output — and none falls through to an
   action.
5. [docs/PRIVACY.md](docs/PRIVACY.md) is updated in the same pull request for
   any new provider, host or outgoing data. The person sees what will be sent
   before it is sent. Keys live in Keychain only.
6. Instructions hidden in the content it reads cannot change what it does, with
   a test showing so.
7. The non-AI way of doing the task still works.
8. It was verified on a real Mac, naming the provider used.

## Strings and languages

English comes first. Every user-facing string lives in `Core/Localization.swift`
as a field of `Strings`, or in a feature catalog in `Core/`. The compiler
requires every language catalog to provide each field. Until translation work
resumes, give non-English catalogs the English text for new fields. Do not mix
translation changes into feature pull requests; translations get their own
pass.

## Sensors on new chips

Temperature mapping lives in `SystemMonitor.prepareSensorsIfNeeded()`. CPU keys
look like `Tp…` and `Te…`, GPU keys `Tg…`, battery keys `TB0T` to `TB2T`. If a
new chip renames them, run `./build/PowerTools --sensors` and open a pull
request with the dump and the adjusted prefixes.

## Reporting bugs and requesting features

Use the issue forms.

- **Bug report.** Include the version from Settings › About, your macOS version
  and Mac model, and steps to reproduce. For AI problems, say whether it ran on
  device or through a provider, and which one. Never paste an API key or private
  content.
- **Feature request.** Describe the problem you want solved, not only a
  solution.

For other help, see [support](SUPPORT.md). Report security problems privately,
as described in [SECURITY.md](SECURITY.md).

## Pull requests

1. One topic per pull request. Say what a person would notice before and after.
2. Keep it small, aiming under about 200 changed lines. Split larger work into
   pieces that stand on their own.
3. `./build.sh` finishes without warnings, `--selftest` passes and
   `./build.sh --test` passes.
4. Match the style of the file you are editing.
5. Write commit summaries as a plain imperative sentence, as `git log` shows.
6. Link issues as `Refs #123`, each on its own line. Not `Closes` or `Fixes`: an
   issue closes once the reporter confirms the fix on a released build.
7. Leave `CHANGELOG.md` alone. The maintainer writes entries when merging.
8. Fix the cause, and name the sibling call sites you checked.
9. Verify on a real Mac and say where: Mac model, macOS version and build,
   Apple Intelligence on or off, AI provider, app language, permissions. Then
   say what you could not test.
10. A new feature is not ready the day it compiles. Use your own build for a few
    days first.
11. Unfinished work is welcome as a **draft**, naming what is missing or which
    decision you need.
12. Agent-assisted work follows [AGENTS.md](AGENTS.md). Read what the agent
    wrote before sending it, mark what you have not confirmed, and answer review
    yourself.

## Review

The maintainer reviews every pull request, and personally approves every AI,
agent-assisted, provider, privacy, permission and networking change.

## Releases (maintainers)

```sh
git tag vX.Y.Z && git push origin vX.Y.Z
```

Only an owner-created, protected version tag can enter the `release-signing`
environment. After owner approval, the workflow builds, signs with the Developer
ID identity and `Resources/PowerTools.entitlements`, notarises through
`Tools/notarize.sh` (secrets `NOTARY_API_KEY_P8`, `NOTARY_KEY_ID`,
`NOTARY_ISSUER_ID`) and publishes the DMG as a GitHub release.

Before tagging, confirm that [docs/PRIVACY.md](docs/PRIVACY.md) describes
exactly what the release does.
