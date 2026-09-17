// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 PowerTools AI contributors

import Foundation

/// Template text for the `HealthFinding` kinds `SystemHealthCondition` never
/// had (`docs/ai-health-coach/`). English only for now (roadmap D5); every
/// other language repeats the English text until translation resumes.
struct HealthCoachStrings {
    let pageTitle: String
    let hubDescription: String
    let settingsIntro: String
    let sensitivitySectionTitle: String
    let memoryHogThresholdLabel: String
    let thermalThrottling: String
    let memoryPressureWarning: String
    /// %1 = app name, %2 = percent of total RAM, already rounded to a whole number
    let memoryHogFormat: String
    /// %1 = swap used now, %2 = swap used before, both already formatted ("2.1 GB")
    let swapGrowthFormat: String
    /// %1 = app name, %2 = CPU percent, already rounded to a whole number
    let cpuSustainedFormat: String
    /// %1 = app name, %2 = the activity phrase below, %3 = memory footprint,
    /// already formatted ("9.2 GB") — used when the sighting came from a
    /// memory row, which is the one worth quoting a size for.
    let activityWithMemoryFormat: String
    /// Same as above when the sighting only appeared in the CPU rows: %3 is
    /// CPU percent, already rounded to a whole number.
    let activityWithCPUFormat: String

    let activityCompiling: String
    let activityRustBuild: String
    let activityJavaScriptTooling: String
    let activitySpotlightIndexing: String
    let activityTimeMachineBackup: String
    let activityPhotosAnalysis: String
    let activitySystemUpdate: String
    let activityICloudSync: String
    let activityVirtualMachine: String

    func phrase(for activity: HealthActivity) -> String {
        switch activity {
        case .compiling: return activityCompiling
        case .rustBuild: return activityRustBuild
        case .javaScriptTooling: return activityJavaScriptTooling
        case .spotlightIndexing: return activitySpotlightIndexing
        case .timeMachineBackup: return activityTimeMachineBackup
        case .photosAnalysis: return activityPhotosAnalysis
        case .systemUpdate: return activitySystemUpdate
        case .iCloudSync: return activityICloudSync
        case .virtualMachine: return activityVirtualMachine
        }
    }

    // MARK: - Narration and limits (task 06)

    let narrationSectionTitle: String
    let narrationModeLabel: String
    let narrationModeOff: String
    let narrationModeOnDemand: String
    let narrationModeWhenSomethingChanges: String
    let narrationModeScheduled: String
    let narrationChangeSeverityLabel: String
    let narrationScheduledIntervalLabel: String
    let severityNotable: String
    let severityCritical: String
    /// %1 = minutes
    let scheduledIntervalFormat: String

    let limitsSectionTitle: String
    let limitsPerHourLabel: String
    let limitsPerDayLabel: String
    /// %1 = calls today, %2 = calls this hour
    let limitsUsageFormat: String
    let limitsResetButton: String

    // MARK: - Narrator (task 07)

    let narratorExplainButton: String
    let narratorSparkleAccessibilityLabel: String
    let narratorSourceOnDevice: String
    /// %1 = a relative time ("2m ago"), %2 = `narratorSourceOnDevice` or a
    /// cloud provider's display name
    let narratorExplainedFormat: String
    let narratorExplainAgainButton: String
    let narratorCancelButton: String
    /// The content-type label the pre-send preview shows the first time a
    /// configured cloud provider is about to receive a health snapshot —
    /// `AIContextManifest.contentTypeLabel`, not specific to any one provider.
    let narratorPreviewContentTypeLabel: String

    // MARK: - Cloud redaction (task 08, Decision D6)

    let redactionSectionTitle: String
    let redactionToggleLabel: String
    let redactionToggleFootnote: String
    let categoryCodeEditor: String
    let categoryBrowser: String
    let categoryCommunication: String
    let categoryMedia: String
    let categoryDesign: String
    let categoryProductivity: String
    let categoryTerminal: String
    /// The fallback for any app `HealthAppCategoryTable` does not name —
    /// what keeps an unrecognised app's real name from ever reaching a
    /// cloud provider when redaction is on, table coverage aside.
    let categoryGeneric: String

    func label(for category: HealthAppCategory) -> String {
        switch category {
        case .codeEditor: return categoryCodeEditor
        case .browser: return categoryBrowser
        case .communication: return categoryCommunication
        case .media: return categoryMedia
        case .design: return categoryDesign
        case .productivity: return categoryProductivity
        case .terminal: return categoryTerminal
        }
    }

    // MARK: - Clipboard activity (task 09, Decision D2)

    /// Shown only once Clipboard History is installed - hidden otherwise,
    /// since the toggle would do nothing without it.
    let clipboardCaptureToggleLabel: String
    let clipboardCaptureToggleFootnote: String

    /// Only `.notable` and `.critical` are offered: `.info` findings (a
    /// recognised activity, an available update) are routine, not something
    /// worth spending a model call to narrate every time one appears.
    func label(for severity: HealthFinding.Severity) -> String? {
        switch severity {
        case .info: return nil
        case .notable: return severityNotable
        case .critical: return severityCritical
        }
    }

    func label(for mode: HealthCoachTriggerSettings.Mode) -> String {
        switch mode {
        case .off: return narrationModeOff
        case .onDemand: return narrationModeOnDemand
        case .whenSomethingChanges: return narrationModeWhenSomethingChanges
        case .scheduled: return narrationModeScheduled
        }
    }

    // MARK: - Detail popover and journal (task 05)

    let detailFindingsSectionTitle: String
    let detailNoFindingsText: String
    let detailActivitySectionTitle: String
    let detailJournalEmptyText: String
    let detailClearActivity: String
    let detailCollapseButton: String

    let journalKeepAwakeStartedManual: String
    let journalKeepAwakeStartedAutomatic: String
    let journalKeepAwakeEnded: String
    let journalRecordingStarted: String
    /// %1 = duration, already formatted ("5m")
    let journalRecordingStoppedFormat: String
    /// %1 = the source app's name only (task 09, D2) — never content
    let journalClipboardCapturedFormat: String
    /// %1 = one of the kindLabel* phrases below
    let journalFindingRaisedFormat: String
    let journalFindingClearedFormat: String

    let kindLabelBatteryLow: String
    let kindLabelThermal: String
    let kindLabelMemoryPressureCritical: String
    let kindLabelDiskLow: String
    let kindLabelMemoryPressureWarning: String
    let kindLabelMemoryHog: String
    let kindLabelSwapGrowth: String
    let kindLabelCPUSustained: String
    let kindLabelKnownActivity: String
    let kindLabelUpdateAvailable: String

    func label(for kind: HealthFinding.Kind) -> String {
        switch kind {
        case .batteryLow: return kindLabelBatteryLow
        case .thermal: return kindLabelThermal
        case .memoryPressureCritical: return kindLabelMemoryPressureCritical
        case .diskLow: return kindLabelDiskLow
        case .memoryPressureWarning: return kindLabelMemoryPressureWarning
        case .memoryHog: return kindLabelMemoryHog
        case .swapGrowth: return kindLabelSwapGrowth
        case .cpuSustained: return kindLabelCPUSustained
        case .knownActivity: return kindLabelKnownActivity
        case .updateAvailable: return kindLabelUpdateAvailable
        }
    }
}

extension FeatureStrings {
    static func healthCoach(_ language: AppLanguage) -> HealthCoachStrings {
        switch language {
        case .enUS: return .enUS
        case .ptBR: return .enUS
        case .tr: return .enUS
        case .ru: return .enUS
        case .es: return .enUS
        case .de: return .enUS
        case .fr: return .enUS
        case .it: return .enUS
        case .ja: return .enUS
        case .ko: return .enUS
        case .zhHans: return .enUS
        case .zhTW: return .enUS
        case .zhHK: return .enUS
        }
    }
}

extension HealthCoachStrings {
    static let enUS = HealthCoachStrings(
        pageTitle: "Health Coach",
        hubDescription: "Notices when something on your Mac is off and says what is causing it, in plain words.",
        settingsIntro: "The panel header already names what is using memory or CPU, right down to a recognised build or backup, from readings PowerTools already takes. Nothing here is sent anywhere, and no AI runs without you asking for it.",
        sensitivitySectionTitle: "Sensitivity",
        memoryHogThresholdLabel: "Flag an app using over",
        thermalThrottling: "Your Mac is running warm and slowing down.",
        memoryPressureWarning: "Memory pressure is building up.",
        memoryHogFormat: "%1$@ is using %2$d%% of your memory.",
        swapGrowthFormat: "Swap use has grown to %1$@, from %2$@.",
        cpuSustainedFormat: "%1$@ has been using %2$d%% CPU for a while.",
        activityWithMemoryFormat: "%1$@ is running %2$@, using %3$@.",
        activityWithCPUFormat: "%1$@ is running %2$@, using %3$d%% CPU.",
        activityCompiling: "a build",
        activityRustBuild: "a Rust build",
        activityJavaScriptTooling: "a JavaScript build or dev server",
        activitySpotlightIndexing: "Spotlight indexing",
        activityTimeMachineBackup: "a Time Machine backup",
        activityPhotosAnalysis: "Photos analysis",
        activitySystemUpdate: "a system update",
        activityICloudSync: "an iCloud sync",
        activityVirtualMachine: "a container or virtual machine",
        narrationSectionTitle: "Narration",
        narrationModeLabel: "Explain automatically",
        narrationModeOff: "Off",
        narrationModeOnDemand: "Only when I press Explain",
        narrationModeWhenSomethingChanges: "When something changes",
        narrationModeScheduled: "On a schedule",
        narrationChangeSeverityLabel: "Worth explaining starting at",
        narrationScheduledIntervalLabel: "How often",
        severityNotable: "Notable",
        severityCritical: "Critical",
        scheduledIntervalFormat: "Every %1$d minutes",
        limitsSectionTitle: "Limits",
        limitsPerHourLabel: "Calls per hour",
        limitsPerDayLabel: "Calls per day",
        limitsUsageFormat: "%1$d today, %2$d this hour",
        limitsResetButton: "Reset counters",
        narratorExplainButton: "Explain",
        narratorSparkleAccessibilityLabel: "AI explanation",
        narratorSourceOnDevice: "On this Mac",
        narratorExplainedFormat: "Explained %1$@ · %2$@",
        narratorExplainAgainButton: "Explain again",
        narratorCancelButton: "Cancel",
        narratorPreviewContentTypeLabel: "Your Mac’s health snapshot",
        redactionSectionTitle: "Cloud providers",
        redactionToggleLabel: "Replace app names with categories",
        redactionToggleFootnote: "When a cloud provider explains something, it hears “a code editor” instead of “Xcode”. Turn this off to send real app names for a more specific explanation. This never applies on this Mac or to a local server, since nothing leaves the Mac either way.",
        categoryCodeEditor: "a code editor",
        categoryBrowser: "a browser",
        categoryCommunication: "a communication app",
        categoryMedia: "a media app",
        categoryDesign: "a design app",
        categoryProductivity: "a productivity app",
        categoryTerminal: "a terminal",
        categoryGeneric: "an app",
        clipboardCaptureToggleLabel: "Note when something is copied",
        clipboardCaptureToggleFootnote: "Recent activity shows only which app you copied from, never what you copied. Off by default. Ignored apps in Clipboard History settings are never recorded here either.",
        detailFindingsSectionTitle: "Findings",
        detailNoFindingsText: "Nothing notable right now.",
        detailActivitySectionTitle: "Recent activity",
        detailJournalEmptyText: "No activity yet.",
        detailClearActivity: "Clear",
        detailCollapseButton: "Collapse",
        journalKeepAwakeStartedManual: "Keep Awake turned on",
        journalKeepAwakeStartedAutomatic: "Keep Awake turned on automatically",
        journalKeepAwakeEnded: "Keep Awake turned off",
        journalRecordingStarted: "Screen recording started",
        journalRecordingStoppedFormat: "Screen recording stopped, %1$@",
        journalClipboardCapturedFormat: "Copied something from %1$@",
        journalFindingRaisedFormat: "%1$@ started",
        journalFindingClearedFormat: "%1$@ cleared",
        kindLabelBatteryLow: "Low battery",
        kindLabelThermal: "Thermal throttling",
        kindLabelMemoryPressureCritical: "Critical memory pressure",
        kindLabelDiskLow: "Low storage",
        kindLabelMemoryPressureWarning: "Memory pressure",
        kindLabelMemoryHog: "High memory use",
        kindLabelSwapGrowth: "Swap growth",
        kindLabelCPUSustained: "Sustained CPU use",
        kindLabelKnownActivity: "A recognised activity",
        kindLabelUpdateAvailable: "An update"
    )
}
