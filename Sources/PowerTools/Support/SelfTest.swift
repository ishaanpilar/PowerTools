// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint
// Copyright (C) 2026 PowerTools contributors

import AppKit
import IOKit.pwr_mgt
import SwiftUI

/// Quick subsystem check, run with `PowerTools --selftest`.
/// Core capabilities fail the test; hardware-dependent readings only warn.
enum SelfTest {
    static func runAndExit() -> Never {
        var failures: [String] = []
        var warnings: [String] = []

        var assertionID = IOPMAssertionID(0)
        let result = IOPMAssertionCreateWithName("PreventUserIdleSystemSleep" as CFString,
                                                 IOPMAssertionLevel(kIOPMAssertionLevelOn),
                                                 "PowerTools selftest" as CFString,
                                                 &assertionID)
        if result == kIOReturnSuccess {
            IOPMAssertionRelease(assertionID)
        } else {
            failures.append("power assertion (\(result))")
        }

        if let memory = SystemInfo.memoryUsage() {
            if memory.total == 0 || memory.used > memory.total || memory.appUsed > memory.total
                || memory.compressed > memory.total || memory.cached > memory.total {
                failures.append("memory bounds")
            } else if memory.used == 0 {
                // Virtualized hosts can transiently report every page as
                // reclaimable cache; the reading is bounded but not useful.
                warnings.append("memory usage unavailable")
            }
            if memory.swapUsed == nil {
                failures.append("swap memory reading")
            }
        } else {
            failures.append("memory reading")
        }
        _ = SystemInfo.batterySnapshot() // may be nil on desktops

        if SystemInfo.wallClockUptimeSeconds() == nil {
            failures.append("uptime reading")
        }

        if let smc = SMCClient() {
            let keys = smc.keys { $0.hasPrefix("Tp") || $0.hasPrefix("Te") || $0.hasPrefix("Tg") }
            if keys.isEmpty {
                warnings.append("no SMC temperature keys")
            } else if keys.compactMap({ smc.readValue($0) }).isEmpty {
                warnings.append("SMC keys found but unreadable")
            }
        } else {
            warnings.append("AppleSMC unavailable")
        }

        // The recorder's macOS-conflict check reads the WindowServer's live
        // shortcut table through private calls; when they are gone it falls
        // back to the preferences plist and loses factory keys such as ⌘⇧4.
        if SymbolicHotKeys.liveEntries()?.isEmpty != false {
            warnings.append("symbolic hotkey table unavailable; shortcut conflicts fall back to the plist")
        }

        // Network counters should be readable and never run backwards.
        let net1 = NetworkSampler.readCounters()
        let net2 = NetworkSampler.readCounters()
        if let net1, let net2 {
            if net2.received < net1.received || net2.sent < net1.sent {
                failures.append("network counters decreased")
            }
        } else {
            warnings.append("network counters unavailable")
        }

        let diskCounters = DiskSampler.readCounters()
        let disks = DiskSampler().sample(now: ProcessInfo.processInfo.systemUptime)
        if diskCounters.isEmpty {
            warnings.append("disk counters unavailable")
        }
        if disks.isEmpty {
            warnings.append("no mounted disk volumes found")
        }

        // Power: laptops report battery/adapter flow; some desktops report nothing.
        if PowerSampler(smc: SMCClient()).sample().isEmpty {
            warnings.append("no power metrics on this Mac")
        }

        UserDefaults.standard.set("ok", forKey: "selftest")
        if UserDefaults.standard.string(forKey: "selftest") != "ok" {
            failures.append("UserDefaults")
        }
        UserDefaults.standard.removeObject(forKey: "selftest")

        for style in KeepAwakeActiveIcon.allCases {
            guard let image = BrandGlyph.activeImage(style: style, tint: .orange) else {
                failures.append("Keep Awake icon \(style.rawValue)")
                continue
            }
            if image.size != BrandGlyph.pointSize {
                failures.append("Keep Awake icon size \(style.rawValue)")
            }
            // image.size stays correct even when the symbol inside it is scaled
            // too large, so an overflow only shows as ink clipped by the canvas.
            if inkTouchesEdge(of: image) {
                failures.append("Keep Awake icon \(style.rawValue) is clipped by its canvas")
            }
        }

        // Tools/MakeIcon.swift writes the glyph PNGs at BrandGlyph.pointSize.
        // Changing the canvas in one and not the other would squash the glyph.
        if Bundle.main.url(forResource: "MenuBarIcon", withExtension: "png") == nil {
            warnings.append("menu bar glyph asset not bundled")
        } else if let rep = BrandGlyph.image(active: false)?
            .representations.min(by: { $0.pixelsWide < $1.pixelsWide }) {
            if rep.pixelsWide != Int(BrandGlyph.pointSize.width)
                || rep.pixelsHigh != Int(BrandGlyph.pointSize.height) {
                failures.append("menu bar glyph is \(rep.pixelsWide)×\(rep.pixelsHigh) px at 1x, "
                                + "expected \(Int(BrandGlyph.pointSize.width))×"
                                + "\(Int(BrandGlyph.pointSize.height))")
            }
        } else {
            failures.append("menu bar glyph representations")
        }

        // The brand palette is written down twice: in Theme, for the in-app
        // badge and mark, and in Tools/MakeBrandAssets.swift, which renders the
        // app icon. They are meant to be the same object, so read the colour
        // back out of the shipped icon rather than trusting the two to agree.
        // The sample lands inside the tall left module, well clear of any edge.
        if let iconURL = Bundle.main.url(forResource: "AppIcon", withExtension: "icns"),
           let icon = NSImage(contentsOf: iconURL),
           let rep = icon.representations
               .compactMap({ $0 as? NSBitmapImageRep })
               .first(where: { $0.pixelsWide >= 512 }) {
            // Design space: the mark box is inset 20% into a squircle that is
            // itself inset 6%, and the left module starts at the box's origin.
            let side = CGFloat(rep.pixelsWide)
            let body = side * 0.88, bodyOrigin = side * 0.06
            let markOrigin = bodyOrigin + body * 0.20
            let unit = (body * 0.60) / 84            // 84 design units across
            let x = Int(markOrigin + 16 * unit)      // inside the 33-wide module
            let y = Int(markOrigin + 42 * unit)      // vertically centred
            // The sampled colour is NOT converted: the rep already stores sRGB
            // bytes, and asking for .sRGB again re-converts from a generic RGB
            // space and shifts the value (#A3E635 reads back as #B0E643).
            if let sampled = rep.colorAt(x: x, y: y),
               let expected = NSColor(Theme.brandLime).usingColorSpace(.sRGB) {
                let drift = max(abs(sampled.redComponent - expected.redComponent),
                                abs(sampled.greenComponent - expected.greenComponent),
                                abs(sampled.blueComponent - expected.blueComponent))
                if drift > 0.02 {
                    failures.append("Theme.brandLime and the app icon have drifted apart "
                                    + "(icon sampled "
                                    + String(format: "#%02X%02X%02X",
                                             Int(sampled.redComponent * 255),
                                             Int(sampled.greenComponent * 255),
                                             Int(sampled.blueComponent * 255))
                                    + "); re-run Tools/MakeBrandAssets.swift")
                }
            } else {
                warnings.append("could not sample the app icon's brand colour")
            }
        } else {
            warnings.append("app icon not bundled; brand colour unchecked")
        }

        // The Settings sensor list reads through the monitor's sampling queue.
        // Prove that path answers and finds sensors, end to end, without a UI.
        // No SMC (a VM, some hardware) only warns; no answer at all is a bug.
        final class SensorProbe: @unchecked Sendable { var count = -1 }
        let sensorProbe = SensorProbe()
        let sensorsAnswered = DispatchSemaphore(value: 0)
        Task.detached {
            sensorProbe.count = await SystemMonitor.shared.temperatureSensorReadings().count
            sensorsAnswered.signal()
        }
        if sensorsAnswered.wait(timeout: .now() + 8) == .timedOut {
            failures.append("temperature sensor list did not answer within 8 s")
        } else if sensorProbe.count == 0 {
            warnings.append("no temperature sensors reported (no SMC on this Mac?)")
        }

        for warning in warnings {
            print("SELFTEST WARNING: \(warning)")
        }
        if failures.isEmpty {
            print("SELFTEST OK")
            exit(0)
        } else {
            print("SELFTEST FAILED: \(failures.joined(separator: ", "))")
            exit(1)
        }
    }

    /// Whether any visible pixel of `image` sits on its outermost row or column.
    /// Every menu bar glyph is drawn with a margin, so touching an edge means
    /// the artwork outgrew its canvas and is being cropped.
    private static func inkTouchesEdge(of image: NSImage) -> Bool {
        let sampling = 2
        let wide = Int(image.size.width) * sampling
        let high = Int(image.size.height) * sampling
        guard wide > 0, high > 0,
              let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: wide, pixelsHigh: high,
                                         bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
                                         isPlanar: false, colorSpaceName: .deviceRGB,
                                         bytesPerRow: 0, bitsPerPixel: 0),
              let context = NSGraphicsContext(bitmapImageRep: rep) else { return false }
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = context
        // The context draws in pixels, so fill the whole bitmap.
        image.draw(in: NSRect(x: 0, y: 0, width: CGFloat(wide), height: CGFloat(high)))
        NSGraphicsContext.restoreGraphicsState()

        func visible(_ x: Int, _ y: Int) -> Bool {
            (rep.colorAt(x: x, y: y)?.alphaComponent ?? 0) > 0.05
        }
        for x in 0..<wide where visible(x, 0) || visible(x, high - 1) { return true }
        for y in 0..<high where visible(0, y) || visible(wide - 1, y) { return true }
        return false
    }
}

/// Prints every temperature sensor the monitor would consider, with its
/// classification. Run with `PowerTools --sensors`; handy when porting
/// the sensor mapping to a new chip generation.
enum SensorDump {
    static func runAndExit() -> Never {
        guard let smc = SMCClient() else {
            print("AppleSMC unavailable")
            exit(1)
        }
        let keys = smc.keys { name in
            name.hasPrefix("Tp") || name.hasPrefix("Te") || name.hasPrefix("Tg")
                || name.range(of: "^TB[0-9]T$", options: .regularExpression) != nil
        }
        let cpuPlatform = TemperatureSensorSelector.currentPlatform()
        let hasCPUCoreSet = TemperatureSensorSelector.hasCPUCoreSet(platform: cpuPlatform)
        print("component    key   type   °C")
        for key in keys.sorted(by: { $0.name < $1.name }) {
            guard let value = smc.readValue(key), value > 1, value < 125 else { continue }
            let component: String
            if key.name.hasPrefix("TB") {
                component = "battery"
            } else if key.name.hasPrefix("Tg") {
                component = "gpu"
            } else if hasCPUCoreSet {
                component = TemperatureSensorSelector.isCPUCoreKey(key.name, platform: cpuPlatform) ? "cpu-core" : "cpu-aux"
            } else {
                component = "cpu"
            }
            // Diagnostic output, read by whoever ran the self-test and by
            // scripts, so it stays on a decimal point wherever it runs.
            print(String(format: "%-11@  %@  %@  %6.2f",
                         locale: Locale(identifier: "en_US_POSIX"),
                         component as NSString, key.name, key.dataType, value))
        }
        exit(0)
    }
}
