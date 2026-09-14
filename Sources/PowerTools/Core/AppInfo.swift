// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint
// Copyright (C) 2026 PowerTools contributors

import Foundation

/// Static identity of the app, shared by UI, notifications and tooling.
enum AppInfo {
    static let name = "PowerTools AI"
    static let copyright = "© 2026 PowerTools AI"

    // MARK: - Outward-facing endpoints
    //
    // The repository is real; the rest have no destination yet and are
    // deliberately unresolvable (`.invalid` is reserved by RFC 2606) so a dead
    // link cannot ship quietly. `--test` enforces both halves of that.

    /// The GitHub `owner/repo` the updater polls for releases. Single source of
    /// truth: `repositoryURL` and the release-asset URLs are both built from it.
    static let repositorySlug = "ishaanpilar/PowerTools"
    static let repositoryURL = URL(string: "https://github.com/\(repositorySlug)")!
    /// No separate site yet, so the repository is the project's web presence.
    static let websiteURL = repositoryURL
    // TODO(powertools-branding): replace when these actually exist.
    static let coffeeURL = URL(string: "https://powertools.invalid/support")!
    static let discordURL = URL(string: "https://powertools.invalid/chat")!
    static let socialURL = URL(string: "https://powertools.invalid/social")!

    /// The bundle version. The fallback only applies to the bare binary
    /// (e.g. `--selftest`), never the shipped app, which reads its Info.plist.
    static var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "dev"
    }

    /// True for the local "PowerTools (Developer)" build (bundle id ends in `.dev`).
    /// It is never published and never auto-updates; all work is tested here first.
    static var isDeveloperBuild: Bool {
        (Bundle.main.bundleIdentifier ?? "").hasSuffix(".dev")
    }

    /// True when the current version is a pre-release (e.g. 3.3.4-beta.1 or 3.3.4-rc.1).
    static var isBeta: Bool {
        if isDeveloperBuild && UserDefaults.standard.bool(forKey: DefaultsKey.simulateBetaUI) {
            return true
        }
        let v = version.lowercased()
        return v.contains("-beta") || v.contains("-rc") || v.contains("-alpha")
    }

    /// The git commit a Developer build was compiled from, e.g. "ed2ebba · 2026-06-15 21:30"
    /// (or with a "-dirty" suffix on the SHA for uncommitted changes). build.sh stamps
    /// this into the Developer bundle only, so you can confirm at a glance that the
    /// running dev app matches the source you are about to change. nil in the official app.
    static var buildCommit: String? {
        Bundle.main.object(forInfoDictionaryKey: "PowerToolsBuildCommit") as? String
    }
}
