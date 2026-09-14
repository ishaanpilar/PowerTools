// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint
// Copyright (C) 2026 PowerTools contributors

import Foundation

/// Where a feature picked from the panel's search opens. Small features stay
/// in the panel; anything that needs room leaves it.
enum PanelSearchDestination: Equatable {
    /// A panel section, shown in place with the usual back button.
    case section(PanelSearchSection)
    /// A compact tool the Utilities section already hosts inside the panel.
    case hostedTool(PanelHostedTool)
    /// A tool with a window or overlay of its own; the panel steps aside.
    case window
    /// A preference with no surface besides its Settings page.
    case settings

    var opensInPanel: Bool {
        switch self {
        case .section, .hostedTool: return true
        case .window, .settings: return false
        }
    }
}

/// The panel sections search can open. Mirrors the matching `PanelSectionID`
/// cases without SwiftUI, so the mapping stays under the unit harness.
enum PanelSearchSection: Equatable, CaseIterable {
    case keepAwake, brightness, mixer, system, network, disk, power, fanControl, toggles
}

/// The tools the Utilities section can host in place of its own list.
enum PanelHostedTool: Equatable, CaseIterable {
    case homebrew, appUpdates, media, clipboard, windowLayout, uninstaller, cleaner, urlCleaner
}

extension AppFeature {
    /// Exhaustive on purpose: a feature added later has to choose where it
    /// opens from search instead of silently landing in Settings.
    var panelSearchDestination: PanelSearchDestination {
        switch self {
        case .mixer: return .section(.mixer)
        case .keepAwake: return .section(.keepAwake)
        case .brightness, .extraBrightness: return .section(.brightness)
        case .quickToggles: return .section(.toggles)
        case .monitorCPU, .monitorGPU, .monitorMemory: return .section(.system)
        case .monitorNetwork: return .section(.network)
        case .monitorDisk: return .section(.disk)
        case .monitorPower: return .section(.power)
        case .fanControl: return .section(.fanControl)
        case .homebrew: return .hostedTool(.homebrew)
        case .appUpdates: return .hostedTool(.appUpdates)
        case .mediaTools: return .hostedTool(.media)
        case .clipboardHistory: return .hostedTool(.clipboard)
        case .windowLayout: return .hostedTool(.windowLayout)
        case .uninstaller: return .hostedTool(.uninstaller)
        case .cleaner: return .hostedTool(.cleaner)
        case .urlCleaner: return .hostedTool(.urlCleaner)
        case .screenshot, .screenRecorder, .screenOCR, .colorPicker, .cameraPreview, .scratchpad,
             .quickLauncher, .commandBar, .cleaningMode, .shelf, .textSnippets:
            return .window
        case .switcher, .dockPreview, .dockClick, .windowMaximizer, .autoQuit,
             .scrollInverter, .focusFollowsMouse, .smoothScroll, .mouseAcceleration,
             .mouseNavigation, .mouseButtonShortcuts, .middleClick, .mouseClickDebounce,
             .keyboardDebounce, .superKey, .quitWindowProtection,
             .pastePlain, .finderCutPaste, .finderRename, .diskImageInstaller, .finderActions,
             .soundOutputSwitcher, .micMute, .musicBlock, .bluetoothSleep,
             .radialMenu, .killProcess:
            return .settings
        }
    }
}

struct PanelSearchResults: Equatable {
    var installed: [AppFeature]
    var notInstalled: [AppFeature]

    var opensInPanel: [AppFeature] { installed.filter { $0.panelSearchDestination.opensInPanel } }
    var opensSeparately: [AppFeature] { installed.filter { !$0.panelSearchDestination.opensInPanel } }
    var isEmpty: Bool { installed.isEmpty && notInstalled.isEmpty }
    /// The groups in the order the list draws them, so keyboard selection
    /// walks the same order the eye does.
    var ordered: [AppFeature] { opensInPanel + opensSeparately + notInstalled }
}

enum PanelSearchSupport {
    /// Ranks with the Settings search rules (case, accents and width folded;
    /// exact name, then name, then description), split into installed and not
    /// installed. A blank query lists everything alphabetically.
    static func results(query: String,
                        features: [AppFeature] = AppFeature.allCases,
                        title: (AppFeature) -> String,
                        keywords: (AppFeature) -> [String],
                        isAvailable: (AppFeature) -> Bool) -> PanelSearchResults {
        let items = features
            .map { feature in
                SettingsSearchItem(id: .feature(feature),
                                   destination: feature.settingsDestination,
                                   title: title(feature),
                                   icon: feature.symbolName,
                                   keywords: keywords(feature),
                                   feature: feature)
            }
            .sorted { $0.title.localizedStandardCompare($1.title) == .orderedAscending }
        let ranked = SettingsSearchSupport.matchingItems(query: query, items: items)
            .compactMap(\.feature)
        return PanelSearchResults(installed: ranked.filter(isAvailable),
                                  notInstalled: ranked.filter { !isAvailable($0) })
    }
}
