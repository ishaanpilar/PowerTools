# Changelog

PowerTools is a fork of [Vorssaint](https://github.com/vorssaint/vorssaint-utils).
Releases made under the PowerTools name are recorded here. Everything that
shipped as Vorssaint before the fork is preserved verbatim in
[docs/UPSTREAM-CHANGELOG.md](docs/UPSTREAM-CHANGELOG.md).

## Unreleased

Forked from Vorssaint 3.3.5 and rebranded. No user-facing feature changes yet.

### Identity

- Renamed the app, Swift module, executable and target to PowerTools.
- New bundle identifier `com.powertools.utils` (developer build:
  `com.powertools.utils.dev`), so PowerTools installs alongside Vorssaint
  rather than over it.
- New helper identifiers, notification and pasteboard namespaces, UserDefaults
  suites, launchd labels and Keychain service names under `com.powertools.*`,
  `org.powertools.*` and the short `pwrt.` prefix.
- New closed-lid sudoers rule at `/etc/sudoers.d/powertools-clamshell`.
- Signing identity renamed to `PowerTools Signing`.

### Removed

- Vorssaint's pre-2.5 bundle rename migration (`BundleMigration`), which could
  never fire under a new bundle identifier.
- Vorssaint's legacy `/Applications` cleanup in `build.sh` and its legacy
  sudoers rule paths, both of which would have deleted another project's files.
- A hardcoded path to the upstream author's Desktop in the update showcase
  loader.

### Changed

- Every outward-facing endpoint (website, repository, update feed, support,
  chat, social) now lives in one place in `AppInfo` and is a deliberately
  unresolvable placeholder, so a half-branded build fails closed instead of
  pointing users at upstream. The updater's repository slug is derived from
  `AppInfo.repositorySlug` rather than duplicated.
- The test suite's branding assertions now check the invariant that matters for
  a fork — that no endpoint points back at upstream — instead of pinning
  literal URLs.

### Known gaps

- **The app icon and brandmark are still Vorssaint's artwork.** They are not
  licensed to forks and must be replaced before any build is distributed. See
  [TRADEMARKS.md](TRADEMARKS.md).
- Placeholder endpoints (`*.invalid`, `POWERTOOLS-OWNER`) must be replaced with
  real ones.
- Screenshot sharing, recording sharing and in-app feedback point at a backend
  upstream operates; PowerTools has no equivalent yet.
- In-app highlight images and the update showcase clip still show upstream's UI.
