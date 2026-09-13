// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint
// Copyright (C) 2026 PowerTools contributors

import Foundation

/// Static identity of the app, shared by UI, notifications and tooling.
enum AppInfo {
    static let name = "PowerTools"
    static let copyright = "© 2026 PowerTools"

    // MARK: - Outward-facing endpoints
    //
    // TODO(powertools-branding): every value below is a placeholder and must be
    // replaced before the first public build. They are deliberately unresolvable
    // (`.invalid` is reserved by RFC 2606, and POWERTOOLS-OWNER is not a real
    // GitHub account) so that a half-branded build fails closed instead of
    // quietly pointing users at the upstream project it was forked from.
    // Upstream's TRADEMARKS.md requires a fork to use its own update feed,
    // so `repositorySlug` in particular must never be left as-is.

    /// The GitHub `owner/repo` the updater polls for releases. Single source of
    /// truth: `repositoryURL` and the release-asset URLs are both built from it.
    static let repositorySlug = "POWERTOOLS-OWNER/powertools"
    static let repositoryURL = URL(string: "https://github.com/\(repositorySlug)")!
    static let websiteURL = URL(string: "https://powertools.invalid")!
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
