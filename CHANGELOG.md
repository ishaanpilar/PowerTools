# Changelog

Notable changes to PowerTools AI are recorded here.

## Unreleased

PowerTools AI is being prepared for its first release as an independent
project. No release has shipped yet.

### Identity

- The public name is PowerTools AI; the Swift module, executable, target and
  `.app` bundle stay `PowerTools`.
- The app calls itself PowerTools AI in English: the menu bar and app name,
  Settings, onboarding, window titles, the Finder menu, permission prompts and
  the settings export file name. A name shown on its own, such as the Finder
  menu title, reads PowerTools AI in every language; other languages' sentences
  follow when translations resume.
- Developer builds show as PowerTools AI (Developer).
- Bundle identifier `com.powertools.utils` (developer build:
  `com.powertools.utils.dev`).
- Helper identifiers, notification and pasteboard namespaces, UserDefaults
  suites, launchd labels and Keychain service names use `com.powertools.*`,
  `org.powertools.*` and the short `pwrt.` prefix.
- Closed-lid sudoers rule at `/etc/sudoers.d/powertools-clamshell`.
- Signing identity `PowerTools Signing`.

### The mark

- An original mark: three rounded modules — one tall, two stacked — in volt lime
  `#A3E635` with a single mint `#00E5A0` module, on a near-black squircle.
- `Tools/MakeBrandAssets.swift` defines the mark's geometry once and renders
  every rendition from it: app icon master, mono master, Icon Composer vector
  and documentation logos.
- `Tools/MakeIcon.swift` sizes the menu bar glyph at 15pt, so the compact square
  mark reads at the same size as other menu bar icons.
- `Theme` carries the brand palette, and `BrandBadge` matches the app icon's
  geometry in About and onboarding.
- `--selftest` samples the brand colour from the shipped app icon and compares
  it with `Theme.brandLime`, so the palette and the icon cannot diverge.

### Added

- Thermal pressure in the System panel, read from the kernel's
  `com.apple.system.thermalpressurelevel` notification: five levels where
  `ProcessInfo.thermalState` exposes four, with no root, helper or subprocess.
- On Intel Macs, the CPU speed limit from `pmset -g therm`. Apple Silicon has no
  equivalent, so nothing is spawned there.
- A thermal throttling alert that notifies when pressure reaches heavy or
  critical, and optionally when throttling clears.
- A browse-only Sensors list in Monitor settings with every SMC temperature
  sensor and live values, read only while the list is open.
- The thermal readings come from
  [MacTelemetry](https://github.com/ishaanpilar/MacTelemetry) (MIT © 2025
  Ishaan Pilar). The `notify_*` bindings use `import notify`, and `pmset` runs
  through the bounded `Shell.run`.

### Changed

- Every outward-facing address (website, repository, update feed, support, chat,
  social) lives in one place, `AppInfo`. The updater's repository comes from
  `AppInfo.repositorySlug`, currently `ishaanpilar/PowerTools`.
- Tests check that no outward-facing address points at another project.

### Removed

- A bundle rename migration, a legacy `/Applications` cleanup in `build.sh` and
  legacy sudoers rule paths, all of which acted on another app's files.
- A hardcoded developer Desktop path in the update showcase loader.

### Known gaps

- The support, chat and social links, screenshot and recording links, and
  in-app feedback point at `*.invalid` placeholders with no service behind them.
- In-app highlight images, the Discord mark in `Resources/Images/` and the
  update showcase clip are inherited media still to be replaced or removed.
