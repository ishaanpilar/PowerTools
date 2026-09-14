// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 PowerTools AI contributors

import Foundation

enum AIActionRegistryTests {
    static let catalogPath = "Sources/PowerTools/Services/CommandBar/CommandBarCatalog.swift"

    static let capture = "Starts an interactive capture or a sensor; the person starts these directly."
    static let interrupts = "Takes the Mac or PowerTools away from the person in the middle of a plan."
    static let destructive = "Destructive; waits for target-bound approval in the plan review (M6)."
    static let writesElsewhere = "Writes into another app or the clipboard."
    static let outside = "Reaches the network or opens content outside PowerTools; no first-release job needs it."
    static let noService = "Has no service behind it (roadmap D9)."
    static let fixedCopy = "A fixed-duration copy of action.keepAwake, which plans use with a number."
    static let barMode = "Switches the Command Bar into a browsing mode rather than doing something."
    static let settingsPage = "Opens one Settings page; action.openSettings covers the first release."

    /// Command Bar rows deliberately unavailable to AI. A new catalog row fails the
    /// suite until it is registered or listed here.
    static let excluded: [String: String] = [
        "action.screenshot": capture,
        "action.scrollingScreenshot": capture,
        "action.screenRecorder": capture,
        "action.screenOCR": capture,
        "action.colorPicker": capture,
        "action.cameraPreview": capture,
        "action.lockScreen": interrupts,
        "action.displayOff": interrupts,
        "action.screenSaver": interrupts,
        "action.cleaningMode": interrupts,
        "action.wifi": interrupts,
        "action.restartApp": interrupts,
        "action.power": interrupts,
        "action.clipboardClearRecent": destructive,
        "action.emptyTrash": destructive,
        "action.ejectDisks": destructive,
        "quit": destructive,
        "kill": destructive,
        "action.pastePlain": writesElsewhere,
        "action.cleanURL": writesElsewhere,
        "menu": writesElsewhere,
        "clipboard": writesElsewhere,
        "snippet": writesElsewhere,
        "emoji": writesElsewhere,
        "selection.cleanLink": writesElsewhere,
        "selection.copy": writesElsewhere,
        "selection.count": writesElsewhere,
        "selection.search": writesElsewhere,
        "selection.shelf": writesElsewhere,
        "answer.battery": writesElsewhere,
        "answer.date": writesElsewhere,
        "answer.memory": writesElsewhere,
        "answer.storage": writesElsewhere,
        "answer.time": writesElsewhere,
        "date.result": writesElsewhere,
        "math.result": writesElsewhere,
        "units.result": writesElsewhere,
        "action.appUpdates": outside,
        "action.openURL": outside,
        "link": outside,
        "file": outside,
        "macsettings": outside,
        "action.feedback.bug": noService,
        "action.feedback.feature": noService,
        "action.keepAwake.30": fixedCopy,
        "action.keepAwake.60": fixedCopy,
        "action.keepAwake.120": fixedCopy,
        "emoji.browse": barMode,
        "kill.browse": barMode,
        "settings": settingsPage,
        "settings.feature": settingsPage,
    ]

    static func run(_ suite: TestSuite) {
        let catalogCode = AIHarnessSource.code(at: catalogPath)
        let rows = CatalogRows(code: catalogCode)

        suite.expect(!catalogCode.isEmpty && !rows.staticIDs.isEmpty,
                     "the registry checks can read CommandBarCatalog.swift")

        var confirmed = Set<String>()
        var confirmationBlocksWithoutID = 0
        for block in rows.rowBlocks where block.contains("confirmationPrompt:") {
            let blockIDs = rows.ids(in: block)
            if blockIDs.isEmpty { confirmationBlocksWithoutID += 1 }
            confirmed.formUnion(blockIDs)
        }
        suite.expect(confirmed.contains("action.emptyTrash") && confirmed.contains("action.clipboardClearRecent"),
                     "the catalog parser finds the rows the Command Bar confirms")

        suite.expect(rows.staticIDs.contains("action.keepAwake.30") && rows.staticIDs.contains("emoji.browse")
                        && rows.templatePrefixes.contains("settings.feature")
                        && rows.templatePrefixes.contains("action.soundOutput"),
                     "the catalog parser finds ids that are not written as id literals")

        let unknownNonLiteral = rows.nonLiteralIDs.subtracting(CatalogRows.understoodNonLiteralIDs)
        suite.expect(unknownNonLiteral.isEmpty,
                     "every non-literal row id is one the catalog parser understands"
                        + " (unrecognised: \(unknownNonLiteral.sorted()))")

        suite.expect(AIActionRegistry.descriptors.count == Set(AIActionRegistry.descriptors.map(\.id)).count,
                     "every registered action id is unique")

        suite.expect(AIActionRegistry.descriptors.allSatisfy { AIActionRegistry.byID[$0.id] == $0 },
                     "byID finds every registered action")

        let entityIDs = Set(AIActionRegistry.descriptors
            .filter { if case .entity = $0.argument { return true }; return false }
            .map(\.id))
        let plainRegisteredIDs = Set(AIActionRegistry.descriptors.map(\.id)).subtracting(entityIDs)

        let missingRows = AIActionRegistry.descriptors.filter { descriptor in
            if case .entity = descriptor.argument {
                return !rows.templatePrefixes.contains(descriptor.id)
            }
            return !rows.staticIDs.contains(descriptor.id)
        }.map(\.id)
        suite.expect(missingRows.isEmpty,
                     "every registered action is a Command Bar row (missing: \(missingRows.sorted()))")

        let uncoveredStatic = rows.staticIDs.filter { id in
            !plainRegisteredIDs.contains(id)
                && excluded[id] == nil
                && !entityIDs.contains(where: { id.hasPrefix($0 + ".") })
        }
        let uncoveredTemplates = rows.templatePrefixes.filter { prefix in
            !entityIDs.contains(prefix) && excluded[prefix] == nil
        }
        suite.expect(uncoveredStatic.isEmpty && uncoveredTemplates.isEmpty,
                     "every Command Bar row is registered for AI or excluded with a reason"
                        + " (uncovered: \(uncoveredStatic.union(uncoveredTemplates).sorted()))")

        let registeredIDs = Set(AIActionRegistry.descriptors.map(\.id))
        suite.expect(registeredIDs.isDisjoint(with: Set(excluded.keys)),
                     "no row is both registered and excluded")

        let allRowIDs = rows.staticIDs.union(rows.templatePrefixes)
        let staleExclusions = excluded.keys.filter { !allRowIDs.contains($0) }
        suite.expect(staleExclusions.isEmpty,
                     "every exclusion names a row that still exists (stale: \(staleExclusions.sorted()))")

        suite.expect(excluded.values.allSatisfy { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty },
                     "every exclusion has a reason")

        var rangeMismatches: [String] = []
        for descriptor in AIActionRegistry.descriptors {
            guard case .integer(let range, let optional) = descriptor.argument else { continue }
            let matchingBlocks = rows.rowBlocks.filter { rows.ids(in: $0).contains(descriptor.id) }
            guard matchingBlocks.count == 1,
                  let regex = try? NSRegularExpression(pattern: #"numericRange:[^\n]*?(-?\d+)\.\.\.(-?\d+)"#),
                  let match = regex.firstMatch(in: matchingBlocks[0],
                                               range: NSRange(matchingBlocks[0].startIndex..., in: matchingBlocks[0])),
                  let loRange = Range(match.range(at: 1), in: matchingBlocks[0]),
                  let hiRange = Range(match.range(at: 2), in: matchingBlocks[0]),
                  let lo = Int(matchingBlocks[0][loRange]), let hi = Int(matchingBlocks[0][hiRange]),
                  lo...hi == range,
                  matchingBlocks[0].contains("numericIsOptional: true") == optional
            else {
                rangeMismatches.append(descriptor.id)
                continue
            }
        }
        suite.expect(rangeMismatches.isEmpty,
                     "registered number ranges match the Command Bar row"
                        + " (mismatched: \(rangeMismatches))")

        suite.expect(confirmationBlocksWithoutID == 0, "update the catalog parser")

        let confirmedBelowDestructive = confirmed.compactMap { AIActionRegistry.byID[$0] }
            .filter { $0.risk < .destructive }
        suite.expect(confirmedBelowDestructive.isEmpty,
                     "an action the Command Bar confirms is never registered below destructive"
                        + " (offenders: \(confirmedBelowDestructive.map(\.id).sorted()))")

        suite.expect(AIActionRegistry.descriptors.allSatisfy { $0.risk == .reversible && !$0.allowsBackgroundExecution },
                     "until M6 the registry offers only reversible foreground actions")
    }
}

/// Parses the Command Bar catalog's row ids from its source text, for tests that
/// cannot compile `CommandBarCatalog.swift` (it needs live services).
struct CatalogRows {
    /// `id:` values that are not string literals but are still understood.
    static let understoodNonLiteralIDs: Set<String> = [
        "id", "String",
        "CommandBarPreferences.emojiBrowserRowID", "CommandBarPreferences.killProcessBrowserRowID",
    ]

    /// `id: "prefix.\(…)"` or `id = "prefix.\(…)"`; there is no space before the colon.
    static let templatePattern = #"id(?::| =) "([A-Za-z0-9_.-]+)\.\\\("#

    let catalog: String
    let staticIDs: Set<String>
    let templatePrefixes: Set<String>
    /// Text of each row initialiser, from one "CommandBarEntry(" to the next.
    let rowBlocks: [String]

    init(code: String) {
        catalog = code.components(separatedBy: "enum CommandBarCatalog {").dropFirst().joined()
        staticIDs = Set(Self.firstGroups(#"id: "([A-Za-z0-9_.-]+)""#, in: catalog))
            .union(Self.firstGroups(#""(action\.[A-Za-z0-9_.-]+)""#, in: catalog))
            .union([CommandBarPreferences.emojiBrowserRowID, CommandBarPreferences.killProcessBrowserRowID])
        templatePrefixes = Set(Self.firstGroups(Self.templatePattern, in: catalog))
        rowBlocks = Array(catalog.components(separatedBy: "CommandBarEntry(").dropFirst())
    }

    /// Every `id: <something>` that is not a string literal.
    var nonLiteralIDs: Set<String> {
        Set(Self.firstGroups(#"\bid: ([^"\s,)]+)"#, in: catalog))
    }

    func ids(in block: String) -> Set<String> {
        Set(Self.firstGroups(#"id: "([A-Za-z0-9_.-]+)""#, in: block))
            .union(Self.firstGroups(Self.templatePattern, in: block))
    }

    static func firstGroups(_ pattern: String, in text: String) -> [String] {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        return regex.matches(in: text, range: NSRange(text.startIndex..., in: text)).compactMap {
            Range($0.range(at: 1), in: text).map { String(text[$0]) }
        }
    }
}
