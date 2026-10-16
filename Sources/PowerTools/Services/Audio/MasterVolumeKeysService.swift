// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 PowerTools AI contributors

import AppKit
import Combine

/// Makes the volume and mute keys work on outputs with no volume of their
/// own (HDMI and DisplayPort displays), where macOS ignores them. The keys
/// drive the mixer's software volume instead and show the level overlay.
///
/// The tap exists only while that kind of output is the default: on any
/// other output the keys never reach PowerTools and macOS handles them.
final class MasterVolumeKeysService: ObservableObject {
    static let shared = MasterVolumeKeysService()

    @Published private(set) var tapFailed = false

    private var tap: CFMachPort?
    private var source: CFRunLoopSource?
    private var outputObserver: AnyCancellable?
    /// Volume wheels send bursts of presses; with finer steps on, the same
    /// gate the roller uses folds them into single fine steps here.
    private var rollerGate = PreciseVolumeRollerGate()

    /// Whether the keys currently belong to this service. The volume roller
    /// stands aside while they do, so one key press is handled once.
    var isActive: Bool { tap != nil }

    private init() {
        SessionActivity.shared.onChange { [weak self] _ in self?.syncWithPreferences() }
    }

    func syncWithPreferences() {
        let enabled = AppFeature.mixer.isAvailable
            && UserDefaults.standard.bool(forKey: DefaultsKey.masterVolumeKeysEnabled)
        if enabled, outputObserver == nil {
            outputObserver = AppVolumeMixer.shared.$systemOutputUsesSoftwareVolume
                .removeDuplicates()
                .dropFirst()
                .sink { [weak self] _ in
                    // Published before the value lands; read it on the next turn.
                    DispatchQueue.main.async { self?.syncWithPreferences() }
                }
        } else if !enabled {
            outputObserver = nil
        }
        let wanted = enabled && AppVolumeMixer.shared.systemOutputUsesSoftwareVolume
        if SessionActivitySupport.tapShouldRun(featureWanted: wanted,
                                               accessibilityGranted: AXIsProcessTrusted(),
                                               sessionIsActive: SessionActivity.shared.isActive) {
            start()
        } else {
            removeTap()
            tapFailed = false
        }
        if !enabled { LevelOSD.dismiss() }
    }

    func suspend() {
        stop()
    }

    func stop() {
        outputObserver = nil
        removeTap()
        tapFailed = false
    }

    private func removeTap() {
        if let tap { CGEvent.tapEnable(tap: tap, enable: false) }
        if let source {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
        }
        if let tap { CFMachPortInvalidate(tap) }
        tap = nil
        source = nil
        rollerGate.reset()
    }

    private func start() {
        if let tap, !CGEvent.tapIsEnabled(tap: tap) {
            CGEvent.tapEnable(tap: tap, enable: true)
        }
        guard tap == nil else { return }

        let systemDefined = CGEventType(rawValue: CleaningSystemKeyEvent.systemDefinedEventTypeRawValue)!
        let callback: CGEventTapCallBack = { _, type, event, userInfo in
            guard let userInfo else { return Unmanaged.passUnretained(event) }
            let service = Unmanaged<MasterVolumeKeysService>
                .fromOpaque(userInfo)
                .takeUnretainedValue()
            return service.handle(type: type, event: event)
        }
        guard let created = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(1 << systemDefined.rawValue),
            callback: callback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            tapFailed = true
            return
        }

        tap = created
        source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, created, 0)
        if let source {
            CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        }
        CGEvent.tapEnable(tap: created, enable: true)
        tapFailed = false
    }

    /// Runs on the main run loop, where the mixer lives.
    private func handle(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if SessionActivity.shared.isActive, AXIsProcessTrusted(), let tap {
                CGEvent.tapEnable(tap: tap, enable: true)
            } else {
                DispatchQueue.main.async { [weak self] in self?.syncWithPreferences() }
            }
            return Unmanaged.passUnretained(event)
        }
        guard type.rawValue == CleaningSystemKeyEvent.systemDefinedEventTypeRawValue,
              let nsEvent = NSEvent(cgEvent: event),
              nsEvent.subtype.rawValue == 8 else {
            return Unmanaged.passUnretained(event)
        }
        let data1 = nsEvent.data1
        guard let key = PreciseVolumeMediaKey(rawValue: Int32((data1 >> 16) & 0xffff)),
              key != .play else {
            return Unmanaged.passUnretained(event)
        }
        // Key up and auto-repeat both arrive here; only presses act, and the
        // matching key up is swallowed with them so macOS sees neither.
        guard (data1 >> 8) & 0xff == 0x0a else { return nil }

        let mixer = AppVolumeMixer.shared
        let roller = UserDefaults.standard.bool(forKey: DefaultsKey.preciseVolumeRollerEnabled)
        let fine = roller || (event.flags.contains(.maskAlternate) && event.flags.contains(.maskShift))
        switch key {
        case .volumeUp, .volumeDown:
            if roller, let direction = key.rollerDirection,
               !rollerGate.accepts(direction, at: ProcessInfo.processInfo.systemUptime) {
                return nil
            }
            // The output gained a volume of its own since the tap started:
            // hand the key back rather than drop it.
            guard let level = mixer.stepSoftwareOutputVolume(up: key == .volumeUp, fine: fine) else {
                return Unmanaged.passUnretained(event)
            }
            LevelOSD.showVolume(level, muted: false)
        case .mute:
            guard let muted = mixer.toggleSoftwareOutputMute() else {
                return Unmanaged.passUnretained(event)
            }
            LevelOSD.showVolume(mixer.systemOutputVolume ?? 0, muted: muted)
        case .play:
            return Unmanaged.passUnretained(event)
        }
        return nil
    }
}
