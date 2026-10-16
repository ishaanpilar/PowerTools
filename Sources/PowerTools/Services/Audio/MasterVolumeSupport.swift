// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 PowerTools AI contributors

import CoreAudio
import Foundation

/// Decisions behind the master output volume on devices that have none of
/// their own. HDMI and DisplayPort displays expose no volume control, so the
/// system slider and the volume keys do nothing there. The mixer instead
/// re-renders everything headed for such a device through one tap, scaled by
/// the level chosen here.
enum MasterVolumeSupport {
    /// The id the master tap uses beside the per-app rows for build tokens,
    /// render checks and recovery. It cannot collide with a row: row ids are
    /// bundle ids, display names or pid-derived ids.
    static let engineID = "__master_output__"

    /// The device whose volume PowerTools provides in software: the default
    /// output, when it has no settable volume of its own and process taps
    /// exist on this macOS.
    static func softwareVolumeDeviceUID(defaultUID: String?,
                                        hasHardwareVolume: Bool,
                                        tapsSupported: Bool) -> String? {
        guard tapsSupported, !hasHardwareVolume else { return nil }
        return defaultUID
    }

    /// Full volume is untouched passthrough: no tap at all.
    static func needsEngine(level: Double, muted: Bool) -> Bool {
        muted || !MixerRoutingSupport.isUnity(sanitizedLevel(level))
    }

    /// What the master tap plays at. Mute keeps the level, so unmuting
    /// returns to it.
    static func gain(level: Double, muted: Bool) -> Double {
        muted ? 0 : sanitizedLevel(level)
    }

    /// A volume key press, matching macOS: sixteen steps, or sixty-four with
    /// Option and Shift held. A level between steps moves to the next one in
    /// the key's direction rather than by a whole step from where it was.
    static func steppedLevel(_ level: Double, up: Bool, fine: Bool) -> Double {
        let steps = fine ? 64.0 : 16.0
        let position = sanitizedLevel(level) * steps
        // Absorbs the float error of a level that is already on a step.
        let tolerance = 0.001
        let next = up ? (position + tolerance).rounded(.down) + 1
                      : (position - tolerance).rounded(.up) - 1
        return min(max(next / steps, 0), 1)
    }

    /// An app the mixer already re-renders plays straight to the device, past
    /// the master tap, so its own gain has to carry the master gain.
    static func appGain(volume: Double,
                        engineOutputUID: String,
                        softwareDeviceUID: String?,
                        masterGain: Double) -> Double {
        guard engineOutputUID == softwareDeviceUID else { return volume }
        return volume * sanitizedLevel(masterGain)
    }

    /// What the master tap leaves out: PowerTools itself, whose engines play
    /// to the same device and would otherwise be captured and replayed again,
    /// and every app an engine already re-renders. Nil without the own
    /// process, because a tap that could capture its own output must not be
    /// built.
    static func excludedProcesses(ownProcess: AudioObjectID?,
                                  appEngineObjects: [[AudioObjectID]]) -> [AudioObjectID]? {
        guard let ownProcess, ownProcess != 0 else { return nil }
        return Set(appEngineObjects.joined()).union([ownProcess]).sorted()
    }

    static func sanitizedLevel(_ level: Double) -> Double {
        level.isFinite ? min(max(level, 0), 1) : 1
    }

    /// Stored levels keyed by device UID. Unreadable entries are dropped, and
    /// full volume is dropped too: it is what an absent entry already means.
    static func sanitizedLevels(_ raw: [String: Any]) -> [String: Double] {
        var levels: [String: Double] = [:]
        for (uid, value) in raw {
            guard let uid = MixerRoutingSupport.sanitizedDeviceUID(uid),
                  let number = (value as? NSNumber)?.doubleValue,
                  number.isFinite else { continue }
            let level = sanitizedLevel(number)
            if !MixerRoutingSupport.isUnity(level) { levels[uid] = level }
        }
        return levels
    }
}
