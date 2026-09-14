# Task 05 — The production action registry and its agreement with the catalog

| | |
| --- | --- |
| Depends on | Task 04 |
| Size | About 230 lines (40 production, the rest tests) |
| Branch | `ai-harness/05-action-registry` |
| Suite | `ai-harness` |

## Why

Tasks 01–04 test the validator with fixtures. This task adds the real list of
Command Bar rows an AI plan may use — an **allow-list**: anything not in it is
`unknownAction`.

Three things could silently go wrong over time, and each gets a check:

1. **A new Command Bar row appears and nobody decides about AI.** Every row id in
   `CommandBarCatalog.swift` must be either registered or excluded with a written
   reason. A new row fails the suite until someone makes that decision.
2. **A risky row gets registered as harmless.** Rows the Command Bar asks the
   person to confirm (`confirmationPrompt:`) can never be registered below
   `destructive`.
3. **A number range drifts.** A registered number range must equal the row's
   `numericRange`, and "optional" must match `numericIsOptional`.

`CommandBarCatalog.swift` is not in the test build — it needs live services — so
these checks read its source. That is allowed here because they pin exactly the
public contract: row id strings.

**Scope of the first registry:** only reversible, foreground actions, because
the first agent milestone (M4) runs nothing else. Destructive rows wait for the
target-bound approval interface (M6). A policy check keeps it that way until M6
changes it deliberately.

## Read first

- `Sources/PowerTools/Services/CommandBar/CommandBarCatalog.swift` — read only,
  from `enum CommandBarCatalog {` (about line 162) to the end
- `Sources/PowerTools/Services/AI/AIHarnessContracts.swift`
- `Tests/AIHarnessTests.swift`, especially `AIHarnessSource`
- `build.sh` test source list

Before writing, list the ids yourself and compare them with the tables below:

```sh
F=Sources/PowerTools/Services/CommandBar/CommandBarCatalog.swift
grep -oE 'id: "[A-Za-z0-9_.-]+"' "$F" | sort -u            # literal row ids
grep -oE '"action\.[A-Za-z0-9_.-]+"' "$F" | sort -u         # also catches the Keep Awake preset tuples
grep -oE 'id(:| =) "[A-Za-z0-9_.-]*\\\(' "$F" | sort -u     # ids that embed a target
grep -nE '\bid: [^" ]' "$F"                                 # ids from variables or constants
```

Rows whose id is not a string literal, as of 2026-09-14:

| Where | Id | How the test sees it |
| --- | --- | --- |
| Keep Awake presets | `action.keepAwake.30`, `.60`, `.120`, written as tuple strings then `id: id` | the quoted `"action.…"` pattern |
| Settings search rows | `id = "settings.\(page)"`, `id = "settings.feature.\(feature.rawValue)"` | the `id = "…\(` pattern |
| Emoji and process browsers | `CommandBarPreferences.emojiBrowserRowID` (`emoji.browse`), `CommandBarPreferences.killProcessBrowserRowID` (`kill.browse`) | read from the constants, which the test build compiles |
| Toggle helper, presets, settings | `id: id` and the `id: String` declarations | allowed forms |

Any other non-literal form fails `every non-literal row id is one the catalog parser understands`.

If they differ from this task (a row was added, renamed or removed since
2026-09-14), stop and ask the maintainer how to classify it.

## The decisions

### Registered (all `reversible`, foreground only)

| Row id | Argument | Why it is safe for a reviewed plan |
| --- | --- | --- |
| `action.darkMode`, `action.hiddenFiles`, `action.desktopIcons` | none | Flips an appearance or Finder setting; flipping again undoes it |
| `action.micMute`, `action.soundMute` | none | Toggles mute |
| `action.keepAwake` | `.integer(1...480, optional: true)` | A timer or toggle; row line `numericRange: 1...480`, `numericIsOptional: true` |
| `action.volume` | `.integer(0...100, optional: false)` | Sets a level the person can set back |
| `action.brightness` | `.integer(0...100, optional: false)` | Same; offered only once brightness control is set up |
| `action.soundOutput` | `.entity(.audioOutputDevice)` | Switches output between connected devices |
| `action.layout` | `.entity(.windowLayout)` | Moves the frontmost window; layout has restore |
| `toggle` | `.entity(.featureToggle)` | Flips one PowerTools preference |
| `app` | `.entity(.application)` | Opens or brings forward an app |
| `window` | `.entity(.window)` | Focuses a window |
| `folder` | `.entity(.configuredFolder)` | Opens a folder the person configured |
| `action.scratchpad`, `action.snippetLibrary`, `action.clipboardWindow`, `action.recentCaptures`, `action.shelf`, `action.quickLauncher`, `action.openSettings`, `action.cleaner`, `action.uninstaller` | none | Opens a PowerTools window or Settings page; acts on nothing |

### Excluded, with reasons

| Reason | Row ids |
| --- | --- |
| Starts an interactive capture or a sensor; the person starts these directly | `action.screenshot`, `action.scrollingScreenshot`, `action.screenRecorder`, `action.screenOCR`, `action.colorPicker`, `action.cameraPreview` |
| Takes the Mac or PowerTools away from the person in the middle of a plan | `action.lockScreen`, `action.displayOff`, `action.screenSaver`, `action.cleaningMode`, `action.wifi`, `action.restartApp`, `action.power` |
| Destructive; waits for target-bound approval in the plan review (M6) | `action.clipboardClearRecent`, `action.emptyTrash`, `action.ejectDisks`, `quit`, `kill` |
| Writes into another app or the clipboard | `action.pastePlain`, `action.cleanURL`, `menu`, `clipboard`, `snippet`, `emoji`, `selection.cleanLink`, `selection.copy`, `selection.count`, `selection.search`, `selection.shelf`, `answer.battery`, `answer.date`, `answer.memory`, `answer.storage`, `answer.time`, `date.result`, `math.result`, `units.result` |
| Reaches the network or opens content outside PowerTools; no first-release job needs it | `action.appUpdates`, `action.openURL`, `link`, `file`, `macsettings` |
| Has no service behind it (roadmap D9) | `action.feedback.bug`, `action.feedback.feature` |
| A fixed-duration copy of `action.keepAwake`, which plans use with a number | `action.keepAwake.30`, `action.keepAwake.60`, `action.keepAwake.120` |
| Switches the Command Bar into a browsing mode rather than doing something | `emoji.browse`, `kill.browse` |
| Opens one Settings page; `action.openSettings` covers the first release | `settings`, `settings.feature` |

Static `toggle.…` ids (`toggle.scrollInverter.vertical` and others) are covered
by the registered `toggle` entity action.

## Change

### 1. Create `Sources/PowerTools/Services/AI/AIActionRegistry.swift`

```swift
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
```

Each `reversible(…)` entry sits on its own line with 8 spaces of indentation;
two mutation entries match those lines exactly. Start the file with the SPDX
line and `// Copyright (C) 2026 PowerTools AI contributors`.

### 2. `build.sh`

Add `Sources/PowerTools/Services/AI/AIActionRegistry.swift` to the test source
list, after `AIPlanValidator.swift`.

### 3. Create `Tests/AIActionRegistryTests.swift`

```swift
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
        // One entry per line, exactly as in the Excluded table of task 05, e.g.:
        "action.screenshot": capture,
        "action.wifi": interrupts,
        // …
    ]

    static func run(_ suite: TestSuite) {
        // checks below
    }
}
```

List every excluded id from the table on its own line as `"<id>": <reason>,`.
The `"action.wifi": interrupts,` line must appear exactly once; a mutation
removes it.

**Reading the catalog.** Inside the test file:

```swift
struct CatalogRows {
    let staticIDs: Set<String>
    let templatePrefixes: Set<String>
    /// Text of each row initialiser, from one "CommandBarEntry(" to the next.
    let rowBlocks: [String]

    /// `id:` values that are not string literals but are still understood.
    static let understoodNonLiteralIDs: Set<String> = [
        "id", "String",
        "CommandBarPreferences.emojiBrowserRowID", "CommandBarPreferences.killProcessBrowserRowID",
    ]

    let catalog: String

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

    /// `id: "prefix.\(…)"` or `id = "prefix.\(…)"`; there is no space before the colon.
    static let templatePattern = #"id(?::| =) "([A-Za-z0-9_.-]+)\.\\\("#

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
```

These patterns were checked against the catalog on 2026-09-14 with an
equivalent script: every row was covered, no exclusion was stale, all 23
registered ids were real rows, the rows with a `confirmationPrompt` resolved to
`action.clipboardClearRecent`, `action.emptyTrash`, `action.power`, `quit` and
`kill`, and the three number ranges matched. If your implementation reports
anything different, suspect the parser before the catalog.

Read the catalog with `AIHarnessSource.code(at: catalogPath)`. Splitting after
`enum CommandBarCatalog {` skips `CommandBarEntry`'s own initialiser and
`withSubtitle`, which mention `confirmationPrompt` without a row id.

**Checks.**

| Message | Rule |
| --- | --- |
| `the registry checks can read CommandBarCatalog.swift` | code non-empty and `staticIDs` non-empty |
| `the catalog parser finds the rows the Command Bar confirms` | the confirmed set (below) contains `action.emptyTrash` and `action.clipboardClearRecent` |
| `the catalog parser finds ids that are not written as id literals` | `staticIDs` contains `action.keepAwake.30` and `emoji.browse`; `templatePrefixes` contains `settings.feature` and `action.soundOutput` |
| `every non-literal row id is one the catalog parser understands` | `nonLiteralIDs` is a subset of `CatalogRows.understoodNonLiteralIDs`; list the others in the message |
| `every registered action id is unique` | `descriptors.count == Set(descriptors.map(\.id)).count` |
| `byID finds every registered action` | for each descriptor `d`, `byID[d.id] == d` |
| `every registered action is a Command Bar row` | entity descriptors: `templatePrefixes` contains the id; others: `staticIDs` contains it. Put missing ids in the message |
| `every Command Bar row is registered for AI or excluded with a reason` | a static id is covered if registered, excluded, or starts with a registered entity id followed by `.`; a template prefix is covered if registered as an entity or excluded. List uncovered ids in the message |
| `no row is both registered and excluded` | registry ids and `excluded` keys do not intersect |
| `every exclusion names a row that still exists` | each `excluded` key is in `staticIDs ∪ templatePrefixes` |
| `every exclusion has a reason` | each value is non-empty after trimming |
| `registered number ranges match the Command Bar row` | for each `.integer(range, optional)` descriptor: exactly one row block whose `ids(in:)` contains the id; in it the first match of `numericRange:[^\n]*?(-?\d+)\.\.\.(-?\d+)` equals `range`, and `block.contains("numericIsOptional: true") == optional` |
| `an action the Command Bar confirms is never registered below destructive` | confirmed set = union of `ids(in:)` over blocks containing `confirmationPrompt:`; every such block names at least one id (otherwise fail with "update the catalog parser"); no registered descriptor in that set has `risk < .destructive` |
| `until M6 the registry offers only reversible foreground actions` | every descriptor is `.reversible` with `allowsBackgroundExecution == false` |

The number-range check needs both capture groups, so use
`NSRegularExpression.firstMatch` directly rather than `firstGroups`.

### 4. `Tests/AIHarnessTests.swift`

At the end of `AIHarnessTests.run`, call `AIActionRegistryTests.run(suite)`.

### 5. `Tests/mutation_checks.py`

```python
    ("keep-awake range drifts from its row", "ai-harness", "Sources/PowerTools/Services/AI/AIActionRegistry.swift",
     'reversible("action.keepAwake", .integer(1...480, optional: true)),',
     'reversible("action.keepAwake", .integer(1...600, optional: true)),',
     "registered number ranges match the Command Bar row"),
    ("confirmed row registered as reversible", "ai-harness", "Sources/PowerTools/Services/AI/AIActionRegistry.swift",
     '        reversible("action.darkMode"),',
     '        reversible("action.darkMode"),\n        reversible("action.emptyTrash"),',
     "an action the Command Bar confirms is never registered below destructive"),
    ("catalog row left undecided", "ai-harness", "Tests/AIActionRegistryTests.swift",
     '"action.wifi": interrupts,',
     '',
     "every Command Bar row is registered for AI or excluded with a reason"),
```

## Done when

- `./build.sh --test-suite=ai-harness`, `./build.sh --test` and `./build.sh` pass.
- `python3 Tests/mutation_checks.py` passes with all eight harness mutations,
  after `git add` of both new files.
- Temporarily adding a row id to a copy of the catalog is not required; the
  "undecided" mutation proves the exhaustiveness check.

## Out of scope

Building the live availability snapshot from `CommandBarCatalog.build` (M4).
Refusing a `toggle` step that would switch off the feature hosting the AI
surface (M4). Command Bar ⌘K row actions in `CommandBarService.swift` (quit,
force quit, kill, uninstall): they are not rows, and stay unavailable to AI
until a milestone registers them as destructive.
