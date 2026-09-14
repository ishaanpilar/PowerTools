// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint
// Copyright (C) 2026 PowerTools contributors

import Foundation

enum PanelSearchTests {
    static func run(_ suite: TestSuite) {
        destinationChecks(suite)
        rankingChecks(suite)
        shortcutChecks(suite)
    }

    private static func destinationChecks(_ suite: TestSuite) {
        let destinations = AppFeature.allCases.map(\.panelSearchDestination)
        suite.expect(PanelSearchSection.allCases.allSatisfy { section in
            destinations.contains(.section(section))
        }, "every searchable panel section is reached by at least one feature")
        suite.expect(PanelHostedTool.allCases.allSatisfy { tool in
            destinations.filter { $0 == .hostedTool(tool) }.count == 1
        }, "every hosted panel tool belongs to exactly one feature")

        suite.expect(AppFeature.mixer.panelSearchDestination == .section(.mixer)
                     && AppFeature.quickToggles.panelSearchDestination == .section(.toggles)
                     && AppFeature.monitorGPU.panelSearchDestination == .section(.system),
                     "sections that live in the panel open there")
        suite.expect(AppFeature.cleaner.panelSearchDestination == .hostedTool(.cleaner)
                     && AppFeature.mediaTools.panelSearchDestination == .hostedTool(.media)
                     && AppFeature.clipboardHistory.panelSearchDestination == .hostedTool(.clipboard),
                     "tools with a compact panel version open it in place")
        suite.expect(AppFeature.screenshot.panelSearchDestination == .window
                     && AppFeature.scratchpad.panelSearchDestination == .window,
                     "tools with their own window leave the panel")
        suite.expect(AppFeature.switcher.panelSearchDestination == .settings
                     && AppFeature.superKey.panelSearchDestination == .settings,
                     "preferences without a surface of their own open Settings")
        suite.expect(PanelSearchDestination.section(.mixer).opensInPanel
                     && PanelSearchDestination.hostedTool(.cleaner).opensInPanel
                     && !PanelSearchDestination.window.opensInPanel
                     && !PanelSearchDestination.settings.opensInPanel,
                     "only sections and hosted tools count as opening in the panel")
    }

    private static func rankingChecks(_ suite: TestSuite) {
        let names: [AppFeature: String] = [
            .cleaner: "Cleaner",
            .cleaningMode: "Cleaning mode",
            .uninstaller: "Uninstaller",
            .mixer: "Volume mixer",
            .screenshot: "Écran capture",
        ]
        let descriptions: [AppFeature: String] = [
            .uninstaller: "Removes an app and cleans its leftovers",
            .mixer: "Per app volume",
        ]
        let features = Array(names.keys)
        func search(_ query: String, installed: Set<AppFeature> = Set(names.keys)) -> PanelSearchResults {
            PanelSearchSupport.results(query: query,
                                       features: features,
                                       title: { names[$0] ?? "" },
                                       keywords: { [descriptions[$0] ?? ""] },
                                       isAvailable: { installed.contains($0) })
        }

        let blank = search("  ")
        suite.expect(blank.ordered.count == features.count,
                     "a blank query lists every feature")
        suite.expect(blank.installed.map { names[$0] ?? "" }
                        == ["Cleaner", "Cleaning mode", "Écran capture", "Uninstaller", "Volume mixer"],
                     "a blank query lists features alphabetically")

        let clean = search("clean")
        suite.expect(clean.installed.first == .cleaner,
                     "a name match ranks above a description match")
        suite.expect(clean.installed.last == .uninstaller,
                     "a description match still finds the feature")
        suite.expect(search("CLEANER").installed.first == .cleaner,
                     "an exact name wins regardless of case")
        suite.expect(search("ecran").installed == [.screenshot],
                     "accents are ignored while matching")
        suite.expect(search("zzz").isEmpty, "a query with no match returns nothing")

        let split = search("clean", installed: [.cleaner])
        suite.expect(split.installed == [.cleaner]
                     && split.notInstalled == [.cleaningMode, .uninstaller],
                     "features that are not installed stay listed, apart from installed ones")

        let grouped = search("", installed: [.cleaner, .screenshot, .mixer])
        suite.expect(grouped.opensInPanel == [.cleaner, .mixer]
                     && grouped.opensSeparately == [.screenshot]
                     && grouped.ordered == [.cleaner, .mixer, .screenshot, .cleaningMode, .uninstaller],
                     "keyboard order follows the drawn groups: panel, separate, not installed")
    }

    private static func shortcutChecks(_ suite: TestSuite) {
        let roleDefaults = GlobalShortcutRole.allCases.map(\.defaultShortcut)
        suite.expect(!roleDefaults.contains(.panelSearchDefault),
                     "the feature search shortcut does not reuse another feature's default")
        suite.expect(GlobalShortcut.panelSearchDefault.isValid,
                     "the feature search shortcut default is a valid global shortcut")
        suite.expect(Defaults.registeredDefaults[DefaultsKey.panelSearchShortcutEnabled] as? Bool == true
                     && Defaults.registeredDefaults[DefaultsKey.panelSearchShortcut] as? String
                        == GlobalShortcut.panelSearchDefault.storageValue,
                     "the feature search shortcut starts on with its default combination")
    }
}
