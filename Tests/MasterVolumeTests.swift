// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 PowerTools AI contributors

import CoreAudio
import Foundation

enum MasterVolumeTests {
    static func run(_ suite: TestSuite) {
        deviceChecks(suite)
        gainChecks(suite)
        exclusionChecks(suite)
        keyStepChecks(suite)
        storageChecks(suite)
        dashboardCardChecks(suite)
    }

    private static func source(_ path: String) -> String {
        let text = (try? String(contentsOfFile: path, encoding: .utf8)) ?? ""
        return text.split(separator: "\n", omittingEmptySubsequences: false)
            .filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//") }
            .joined(separator: "\n")
    }

    private static func dashboardCardChecks(_ suite: TestSuite) {
        suite.expect(Defaults.registeredDefaults[DefaultsKey.panelDashboardShowVolume] as? Bool == false,
                     "the Volume card joins the dashboard only when turned on")
        let dashboard = source("Sources/PowerTools/UI/MenuPanel/PanelDashboard.swift")
        suite.expect(dashboard.contains("case cpu, memory, storage, network, gpu, battery, volume"),
                     "Volume is one of the reorderable, hideable dashboard cards, after the readings")
        suite.expect(dashboard.contains("case .volume: return sections.contains(.mixer) && AppFeature.mixer.isAvailable"),
                     "the Volume card follows the Mixer section and goes when the Mixer is uninstalled")
        suite.expect(dashboard.contains("DashboardVolumeTile()")
                        && dashboard.contains("mixer.setCurrentOutputMuted(")
                        && dashboard.contains("mixer.setCurrentOutputVolume("),
                     "the card drives the mixer's shared volume and mute, software volume included")
        let commandBar = source("Sources/PowerTools/Services/CommandBar/CommandBarCatalog.swift")
        suite.expect(commandBar.contains("AppVolumeMixer.shared.setCurrentOutputVolume(")
                        && commandBar.contains("AppVolumeMixer.shared.setCurrentOutputMuted("),
                     "Command Bar volume and mute reach displays without a volume of their own")
    }

    private static func deviceChecks(_ suite: TestSuite) {
        suite.expect(MasterVolumeSupport.softwareVolumeDeviceUID(defaultUID: "DisplayPort-LG",
                                                                 hasHardwareVolume: false,
                                                                 tapsSupported: true) == "DisplayPort-LG",
                     "a default output with no volume of its own gets PowerTools' volume")
        suite.expect(MasterVolumeSupport.softwareVolumeDeviceUID(defaultUID: "BuiltInSpeakerDevice",
                                                                 hasHardwareVolume: true,
                                                                 tapsSupported: true) == nil,
                     "an output with its own volume keeps the native control")
        suite.expect(MasterVolumeSupport.softwareVolumeDeviceUID(defaultUID: "DisplayPort-LG",
                                                                 hasHardwareVolume: false,
                                                                 tapsSupported: false) == nil,
                     "without process taps there is no software volume to offer")
        suite.expect(MasterVolumeSupport.softwareVolumeDeviceUID(defaultUID: nil,
                                                                 hasHardwareVolume: false,
                                                                 tapsSupported: true) == nil,
                     "no default output means no software volume")
    }

    private static func gainChecks(_ suite: TestSuite) {
        suite.expect(!MasterVolumeSupport.needsEngine(level: 1, muted: false),
                     "full volume is untouched passthrough")
        suite.expect(MasterVolumeSupport.needsEngine(level: 0.4, muted: false)
                        && MasterVolumeSupport.needsEngine(level: 0, muted: false),
                     "any lower level, silence included, needs the master tap")
        suite.expect(MasterVolumeSupport.needsEngine(level: 1, muted: true),
                     "mute at full volume still needs the master tap to silence the output")
        suite.expect(!MasterVolumeSupport.needsEngine(level: .nan, muted: false),
                     "an unreadable level falls back to passthrough, never to silence")
        suite.expectClose(MasterVolumeSupport.gain(level: 0.6, muted: true), 0,
                          "mute silences the master tap")
        suite.expectClose(MasterVolumeSupport.gain(level: 0.6, muted: false), 0.6,
                          "unmuted, the master tap plays at the kept level")

        let appVolume = 1.5
        let master = 0.4
        suite.expectClose(MasterVolumeSupport.appGain(volume: appVolume,
                                                      engineOutputUID: "DisplayPort-LG",
                                                      softwareDeviceUID: "DisplayPort-LG",
                                                      masterGain: master),
                          appVolume * master,
                          "an app re-rendered to the software-volume output carries the master level")
        suite.expectClose(MasterVolumeSupport.appGain(volume: appVolume,
                                                      engineOutputUID: "USBHeadset",
                                                      softwareDeviceUID: "DisplayPort-LG",
                                                      masterGain: master),
                          appVolume,
                          "an app routed to another output keeps only its own volume")
        suite.expectClose(MasterVolumeSupport.appGain(volume: appVolume,
                                                      engineOutputUID: "BuiltInSpeakerDevice",
                                                      softwareDeviceUID: nil,
                                                      masterGain: master),
                          appVolume,
                          "with no software-volume output the master level never applies")
    }

    private static func exclusionChecks(_ suite: TestSuite) {
        let own: AudioObjectID = 90
        let rowA: [AudioObjectID] = [41, 12]
        let rowB: [AudioObjectID] = [12, 77]
        let expected = Set(rowA + rowB + [own]).sorted()
        suite.expect(MasterVolumeSupport.excludedProcesses(ownProcess: own,
                                                           appEngineObjects: [rowA, rowB]) == expected,
                     "the master tap leaves out PowerTools and every app a row engine re-renders, once each")
        suite.expect(MasterVolumeSupport.excludedProcesses(ownProcess: own, appEngineObjects: []) == [own],
                     "with no row engines only PowerTools itself is left out")
        suite.expect(MasterVolumeSupport.excludedProcesses(ownProcess: nil, appEngineObjects: [rowA]) == nil
                        && MasterVolumeSupport.excludedProcesses(ownProcess: 0, appEngineObjects: [rowA]) == nil,
                     "no tap is built while PowerTools' own output cannot be excluded from it")
    }

    private static func keyStepChecks(_ suite: TestSuite) {
        let step = 1.0 / 16
        let fineStep = 1.0 / 64
        suite.expectClose(MasterVolumeSupport.steppedLevel(8 * step, up: true, fine: false), 9 * step,
                          "a volume key moves one of sixteen steps up")
        suite.expectClose(MasterVolumeSupport.steppedLevel(8 * step, up: false, fine: false), 7 * step,
                          "and one step down")
        suite.expectClose(MasterVolumeSupport.steppedLevel(8 * step, up: true, fine: true), 8 * step + fineStep,
                          "Option and Shift move a quarter step")
        suite.expectClose(MasterVolumeSupport.steppedLevel(0.5 + step / 3, up: true, fine: false), 9 * step,
                          "a level between steps moves up to the next step, not a whole step past it")
        suite.expectClose(MasterVolumeSupport.steppedLevel(0.5 + step / 3, up: false, fine: false), 8 * step,
                          "and down to the step below it")
        suite.expectClose(MasterVolumeSupport.steppedLevel(1, up: true, fine: false), 1,
                          "volume up stops at full volume")
        suite.expectClose(MasterVolumeSupport.steppedLevel(0, up: false, fine: false), 0,
                          "volume down stops at silence")
        suite.expectClose(MasterVolumeSupport.steppedLevel(3 * step + 1e-9, up: true, fine: false), 4 * step,
                          "float error above a step does not skip the next one")
        suite.expectClose(MasterVolumeSupport.steppedLevel(3 * step - 1e-9, up: true, fine: false), 4 * step,
                          "float error below a step still moves a whole step up")
        suite.expectClose(MasterVolumeSupport.steppedLevel(3 * step + 1e-9, up: false, fine: false), 2 * step,
                          "and a whole step down")
    }

    private static func storageChecks(_ suite: TestSuite) {
        let levels = MasterVolumeSupport.sanitizedLevels([
            "DisplayPort-LG": 0.35,
            "HDMI-Odyssey": NSNumber(value: 4),
            "Loud": -2,
            "Full": 1,
            "Broken": "half",
            "NotANumber": Double.nan,
            "": 0.5,
        ])
        // 4 clamps to full volume, which an absent entry already means.
        suite.expect(levels == ["DisplayPort-LG": 0.35, "Loud": 0],
                     "stored levels clamp to 0...1, drop full volume and drop entries that are not levels")
        suite.expect(SettingsBackupSupport.exportKeys().contains(DefaultsKey.softwareOutputVolumes),
                     "software output levels travel with the settings backup")
    }
}
