# Changelog

Notable changes to PowerTools AI are recorded here.

## [1.0.0-beta.4] - 2026-09-16

### Summary

Always On Top, borrowed from PowerToys: pin the focused window above every
other window with a shortcut. A small visual fix to the menu panel's Liquid
Glass rides along.

### Added

- Always On Top (off by default): `⌃⌥⌘A` pins the focused window above
  every other window; press it again to unpin. Several windows can be
  pinned independently, each outlined with a border that tracks it as it
  moves or resizes. Unpins itself if the window closes. Requires
  Accessibility.

### Fixed

- The menu panel's search and settings buttons now share one Liquid Glass
  sampling region instead of each blurring the desktop independently.
- The panel's Liquid Glass surface no longer has a flat-color tint fighting
  the real material's own contrast and transparency handling.

## [1.0.0-beta.3] - 2026-09-16

### Summary

AI text actions now actually do something: select text anywhere and rewrite,
shorten, proofread, summarise or translate it from the Command Bar, on
whatever provider you connected in 1.0.0-beta.2. This is the feature the
last two releases were building toward.

### Added

- Five Command Bar actions on your selection: Rewrite, Shorten, Proofread,
  Summarise, Translate. Each opens a small panel that streams the answer
  in, with Copy and Replace - nothing is copied or replaces your selection
  until you press one of those buttons, and pressing Escape or clicking
  away does nothing else.
- The first time selected text goes to a given provider, a preview shows
  exactly what's about to be sent, its size, whether it stays on this Mac
  or leaves it, and that provider's privacy policy, before anything sends.
- Translate targets the language PowerTools AI's own interface is set to.

### Changed

- `PRIVACY.md` updated to match: the Command Bar actions described above
  are real now, not upcoming.

## [1.0.0-beta.2] - 2026-09-16

### Summary

The first piece of PowerTools AI's own AI: connecting a provider. Install the
AI text actions feature (off by default) and set up on-device Apple
Intelligence, a cloud provider you bring your own key for, or a local model
server on this Mac. Test the connection before relying on it. The text
actions themselves — rewrite, shorten, proofread, summarise, translate — are
not in the Command Bar yet; this release only gets the provider connection
right.

### Added

- AI text actions, a new Feature Hub entry (off by default) with its own
  Settings page.
- A provider picker: on this Mac with Apple's on-device model (macOS 26,
  Apple Intelligence on), DeepSeek, OpenAI, Anthropic, a custom
  OpenAI-compatible endpoint, or a local server such as Ollama or LM Studio.
- API keys live in the macOS Keychain only, never in Settings, exports or
  logs.
- Test connection sends one real request to confirm a provider works, and
  links to that provider's own privacy policy.
- HTTPS is required for every cloud address; a local server is accepted only
  at a loopback address, so a request can never leave the Mac by accident.
- Underneath, not yet reachable from anywhere in the app: the plan validator
  that will gate future automated actions (risk levels, approvals, a
  capability lease), and a context manifest with a one-time pre-send preview
  for what a request is about to send.

## [1.0.0-beta.1] - 2026-09-14

### Summary

The first beta of PowerTools AI as an independent app. The menu panel opens on
a dashboard, you can search your installed features, first-run setup is
shorter, and the app carries the PowerTools AI name. The AI features themselves
are not in this build yet.

### Added

- The menu panel opens on a dashboard of cards you can reorder and expand in
  place, including a charging card. The header greets you with a live health
  summary, and readings keep refreshing quietly while the panel is idle.
- Search your installed features from the menu panel, or jump straight to the
  search with a global shortcut.
- With no features installed, the panel explains that only installed tools run
  and offers a ready setup or picking features one by one.
- A shorter first-run setup: a brief title with the choices, a permissions step
  limited to what your chosen features use, and a preview of the planned AI
  features that turns nothing on.
- A PowerTools AI submenu in the Finder right-click menu.
- Thermal pressure in the System panel, read from the kernel's
  `com.apple.system.thermalpressurelevel` notification: five levels where
  `ProcessInfo.thermalState` exposes four, with no root, helper or subprocess.
- On Intel Macs, the CPU speed limit from `pmset -g therm`. Apple Silicon has no
  equivalent, so nothing is spawned there.
- A thermal throttling alert that notifies when pressure reaches heavy or
  critical, and optionally when throttling clears.
- A browse-only Sensors list in Monitor settings with every SMC temperature
  sensor and live values, read only while the list is open.
- The thermal readings and the dashboard card design come from
  [MacTelemetry](https://github.com/ishaanpilar/MacTelemetry) (MIT © 2025
  Ishaan Pilar).

### Changed

- The app is called PowerTools AI in English: the menu bar and app name,
  Settings, onboarding, window titles, the Finder menu, permission prompts and
  the settings export file name. A name shown on its own, such as the Finder
  menu title, reads PowerTools AI in every language.
- Every outward-facing address (website, repository, update feed, support, chat,
  social) lives in one place, `AppInfo`. The updater follows
  `AppInfo.repositorySlug`, `ishaanpilar/PowerTools`.
- Tests check that no outward-facing address points at another project.

### Identity

- The public name is PowerTools AI; the Swift module, executable, target and
  `.app` bundle stay `PowerTools`. Developer builds show as PowerTools AI
  (Developer).
- Bundle identifier `com.powertools.utils` (developer build:
  `com.powertools.utils.dev`).
- Helper identifiers, notification and pasteboard namespaces, UserDefaults
  suites, launchd labels and Keychain service names use `com.powertools.*`,
  `org.powertools.*` and the short `pwrt.` prefix.
- Closed-lid sudoers rule at `/etc/sudoers.d/powertools-clamshell`.
- An original mark: three rounded modules — one tall, two stacked — in volt lime
  `#A3E635` with a single mint `#00E5A0` module, on a near-black squircle,
  rendered from one definition in `Tools/MakeBrandAssets.swift`. `--selftest`
  checks the shipped icon against `Theme.brandLime`.

### Removed

- A bundle rename migration, a legacy `/Applications` cleanup in `build.sh` and
  legacy sudoers rule paths, all of which acted on another app's files.
- A hardcoded developer Desktop path in the update showcase loader.

### Known issues

- This beta is not signed with an Apple Developer ID or notarized. The first
  time you open it, allow it in System Settings › Privacy & Security › Open
  Anyway.
- AI features are not included yet.
- Screenshot links, recording links and in-app feedback do not work: there is no
  service behind them, so nothing is uploaded. Support, chat and social links
  are placeholders too.
- In-app highlight images, the Discord mark and the update showcase clip are
  inherited media still to be replaced.
- Languages other than English still say PowerTools in their sentences.
- In Finder, the app file is named PowerTools.
