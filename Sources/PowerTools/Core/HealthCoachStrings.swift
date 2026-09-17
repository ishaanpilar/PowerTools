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
        activityVirtualMachine: "a container or virtual machine"
    )
}
