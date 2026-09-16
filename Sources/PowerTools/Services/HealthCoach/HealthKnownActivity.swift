// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 PowerTools AI contributors

import Foundation

/// Something recognisable a Mac is busy doing, told apart by executable name
/// alone. Names only: never arguments, window titles or file paths.
enum HealthActivity: String, CaseIterable {
    case compiling
    case rustBuild
    case javaScriptTooling
    case spotlightIndexing
    case timeMachineBackup
    case photosAnalysis
    case systemUpdate
    case iCloudSync
    case virtualMachine
}

/// Maps `ps` executable names to activities. `kernel_task` is absent on
/// purpose: `ps` does not list it without root.
enum HealthKnownActivity {
    static let exactNames: [String: HealthActivity] = [
        "swift-frontend": .compiling,
        "swift-build": .compiling,
        "swift-driver": .compiling,
        "clang": .compiling,
        "cc1": .compiling,
        "ld": .compiling,
        "xcodebuild": .compiling,
        "XCBBuildService": .compiling,
        "rustc": .rustBuild,
        "cargo": .rustBuild,
        "node": .javaScriptTooling,
        "tsc": .javaScriptTooling,
        "esbuild": .javaScriptTooling,
        "bun": .javaScriptTooling,
        "deno": .javaScriptTooling,
        "mds_stores": .spotlightIndexing,
        "mdworker_shared": .spotlightIndexing,
        "mdworker": .spotlightIndexing,
        "backupd": .timeMachineBackup,
        "backupd-helper": .timeMachineBackup,
        "photoanalysisd": .photosAnalysis,
        "softwareupdated": .systemUpdate,
        "bird": .iCloudSync,
        "cloudd": .iCloudSync,
    ]

    /// Checked after the exact table; each prefix is a family of executables.
    static let namePrefixes: [(prefix: String, activity: HealthActivity)] = [
        ("com.docker.", .virtualMachine),
        ("qemu-system-", .virtualMachine),
    ]

    /// Exact matches only, so an app merely named after a tool (for example
    /// `Creative Cloud Content Manager.node`) is not mistaken for it.
    static func activity(forProcessName name: String) -> HealthActivity? {
        if let activity = exactNames[name] { return activity }
        return namePrefixes.first { name.hasPrefix($0.prefix) }?.activity
    }
}
