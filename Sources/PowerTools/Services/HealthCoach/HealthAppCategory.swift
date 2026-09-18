// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 PowerTools AI contributors

import Foundation

/// A broad kind of app, told apart by name alone — the redacted stand-in
/// for a real app name when a cloud provider is about to be told about one
/// (Decision D6, `docs/ai-health-coach/README.md` section 9: categories by
/// default, real names an opt-in). Never inferred from anything but the
/// name itself: no bundle identifier lookup, no window title.
enum HealthAppCategory: String, CaseIterable {
    case codeEditor
    case browser
    case communication
    case media
    case design
    case productivity
    case terminal
}

/// Maps an app's own display name (as `ProcessUsage.name` carries it) to a
/// category. Deliberately small and exact-match only, the same discipline
/// `HealthKnownActivity` uses and for the same reason: a name that merely
/// resembles a known one is not the same app. Anything not in this table
/// falls back to a generic label — the point of the fallback, not a gap to
/// fill: it is what keeps an unrecognised app's real name from ever
/// reaching a cloud provider when redaction is on, table coverage aside.
enum HealthAppCategoryTable {
    static let exactNames: [String: HealthAppCategory] = [
        "Xcode": .codeEditor,
        "Code": .codeEditor,
        "Sublime Text": .codeEditor,
        "PyCharm": .codeEditor,
        "IntelliJ IDEA": .codeEditor,
        "Android Studio": .codeEditor,
        "Safari": .browser,
        "Google Chrome": .browser,
        "Firefox": .browser,
        "Microsoft Edge": .browser,
        "Brave Browser": .browser,
        "Arc": .browser,
        "Slack": .communication,
        "Messages": .communication,
        "Mail": .communication,
        "Discord": .communication,
        "Microsoft Teams": .communication,
        "zoom.us": .communication,
        "FaceTime": .communication,
        "Photos": .media,
        "Music": .media,
        "Spotify": .media,
        "QuickTime Player": .media,
        "Final Cut Pro": .media,
        "Photoshop": .design,
        "Illustrator": .design,
        "Lightroom": .design,
        "Figma": .design,
        "Sketch": .design,
        "Notes": .productivity,
        "Reminders": .productivity,
        "Calendar": .productivity,
        "Microsoft Word": .productivity,
        "Microsoft Excel": .productivity,
        "Microsoft PowerPoint": .productivity,
        "Pages": .productivity,
        "Numbers": .productivity,
        "Keynote": .productivity,
        "Notion": .productivity,
        "Obsidian": .productivity,
        "Terminal": .terminal,
        "iTerm2": .terminal,
        "Warp": .terminal,
    ]

    static func category(forAppName name: String) -> HealthAppCategory? {
        exactNames[name]
    }

    /// The redacted stand-in for `name` — a category's own label if the
    /// table recognises the name, `strings.categoryGeneric` otherwise. This,
    /// not the table, is what a caller redacting for a cloud provider
    /// should use: it always returns something safe to send.
    static func label(forAppName name: String, strings: HealthCoachStrings) -> String {
        guard let category = category(forAppName: name) else { return strings.categoryGeneric }
        return strings.label(for: category)
    }
}
