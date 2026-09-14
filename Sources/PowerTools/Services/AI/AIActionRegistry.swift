// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 PowerTools AI contributors

import Foundation

/// The Command Bar rows an AI plan may use; anything absent is unavailable to AI.
/// Rows left out are listed with a reason in Tests/AIActionRegistryTests.swift.
enum AIActionRegistry {
    static let descriptors: [AIActionDescriptor] = [
        reversible("action.darkMode"),
        reversible("action.hiddenFiles"),
        reversible("action.desktopIcons"),
        reversible("action.micMute"),
        reversible("action.soundMute"),
        reversible("action.keepAwake", .integer(1...480, optional: true)),
        reversible("action.volume", .integer(0...100, optional: false)),
        reversible("action.brightness", .integer(0...100, optional: false)),
        reversible("action.soundOutput", .entity(.audioOutputDevice)),
        reversible("action.layout", .entity(.windowLayout)),
        reversible("toggle", .entity(.featureToggle)),
        reversible("app", .entity(.application)),
        reversible("window", .entity(.window)),
        reversible("folder", .entity(.configuredFolder)),
        reversible("action.scratchpad"),
        reversible("action.snippetLibrary"),
        reversible("action.clipboardWindow"),
        reversible("action.recentCaptures"),
        reversible("action.shelf"),
        reversible("action.quickLauncher"),
        reversible("action.openSettings"),
        reversible("action.cleaner"),
        reversible("action.uninstaller"),
    ]

    // uniqueKeysWithValues would crash at launch on a repeated id; the registry test reports it instead.
    static let byID: [String: AIActionDescriptor] = Dictionary(
        descriptors.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })

    private static func reversible(_ id: String, _ argument: AIArgumentKind = .none) -> AIActionDescriptor {
        AIActionDescriptor(id: id, risk: .reversible, argument: argument, allowsBackgroundExecution: false)
    }
}
