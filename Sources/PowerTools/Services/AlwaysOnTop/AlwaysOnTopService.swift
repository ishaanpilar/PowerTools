// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint
// Copyright (C) 2026 PowerTools contributors

import AppKit
import ApplicationServices
import Combine

/// Pins the focused window above every other window with a shortcut, borrowed
/// from PowerToys' "Always On Top". Several windows can be pinned at once,
/// each independently.
///
/// macOS has no public API to reorder another app's window; this uses the
/// same private SkyLight call real "pin window" utilities rely on
/// (`CGSSetWindowLevel`), resolved with `dlopen`/`dlsym` like the dark-mode
/// switch in `QuickTogglesService`. Every pinned window gets its own
/// Accessibility observer so a closed window auto-unpins (mirroring
/// `AutoQuitService`'s per-window observer lifecycle) and a borderless overlay
/// that outlines it and tracks its live frame (mirroring
/// `DockPreviewDragGhost`). `suspend()` must run before the process exits:
/// the level change outlives the process otherwise, since the window belongs
/// to someone else.
final class AlwaysOnTopService: ObservableObject {
    static let shared = AlwaysOnTopService()

    struct PinnedWindowInfo: Identifiable {
        let id: AlwaysOnTopWindowKey
        let appName: String
        let icon: NSImage
        let windowTitle: String
    }

    private struct PinRecord {
        let window: AXUIElement
        let observer: AXObserver
        let overlay: AlwaysOnTopBorderOverlay
    }

    private struct FocusedWindowTarget {
        let key: AlwaysOnTopWindowKey
        let window: AXUIElement
        let appName: String
        let icon: NSImage
        let title: String
    }

    @Published private(set) var pinnedWindows: [AlwaysOnTopWindowKey: PinnedWindowInfo] = [:]
    @Published private(set) var shortcutRegistrationFailed = false

    private var records: [AlwaysOnTopWindowKey: PinRecord] = [:]
    private let hotkey = QuickToolHotkey(id: 26)
    private var terminationObserver: NSObjectProtocol?

    private static let windowNotifications = [
        kAXUIElementDestroyedNotification,
        kAXWindowMovedNotification,
        kAXWindowResizedNotification,
    ]

    private init() {
        hotkey.onPress = { [weak self] in self?.togglePinOnFocusedWindow() }
        terminationObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didTerminateApplicationNotification,
            object: nil, queue: .main
        ) { [weak self] note in
            guard let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else { return }
            self?.unpinAll(pid: app.processIdentifier)
        }
    }

    func syncWithPreferences() {
        let enabled = AppFeature.alwaysOnTop.isAvailable
            && UserDefaults.standard.bool(forKey: DefaultsKey.alwaysOnTopShortcutEnabled)
            && Permissions.shared.accessibility
        let shortcut = GlobalShortcut.saved(for: DefaultsKey.alwaysOnTopShortcut,
                                            fallback: .alwaysOnTopDefault)
        shortcutRegistrationFailed = !hotkey.sync(enabled: enabled, shortcut: shortcut)
        if !enabled { unpinAll() }
    }

    /// Releases every pinned window's level and overlay. Called before the
    /// app quits and whenever the feature or its permission goes away, so a
    /// window is never left floating with no control left to release it.
    func suspend() {
        hotkey.unregister()
        unpinAll()
    }

    func unpin(_ key: AlwaysOnTopWindowKey) {
        guard let record = records.removeValue(forKey: key) else { return }
        CFRunLoopRemoveSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(record.observer), .commonModes)
        Self.setWindowLevel(record.window, level: CGWindowLevelForKey(.normalWindow))
        record.overlay.end()
        pinnedWindows.removeValue(forKey: key)
    }

    private func unpinAll() {
        for key in Array(records.keys) { unpin(key) }
    }

    private func unpinAll(pid: pid_t) {
        for key in records.keys where key.pid == pid { unpin(key) }
    }

    private func togglePinOnFocusedWindow() {
        guard let target = resolveFocusedWindow() else { return }
        if pinnedWindows[target.key] != nil {
            unpin(target.key)
            QuickToolHUD.show(icon: "pin.slash", message: FeatureStrings.alwaysOnTop(L10n.shared.language).hudUnpinned)
        } else {
            pin(target)
        }
    }

    private func pin(_ target: FocusedWindowTarget) {
        guard Self.setWindowLevel(target.window, level: Self.pinnedLevel) else { return }

        var observerRef: AXObserver?
        guard AXObserverCreate(target.key.pid, alwaysOnTopAXCallback, &observerRef) == .success,
              let observer = observerRef else {
            Self.setWindowLevel(target.window, level: CGWindowLevelForKey(.normalWindow))
            return
        }
        let refcon = Unmanaged.passUnretained(self).toOpaque()
        for notification in Self.windowNotifications {
            AXObserverAddNotification(observer, target.window, notification as CFString, refcon)
        }
        CFRunLoopAddSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(observer), .commonModes)

        records[target.key] = PinRecord(window: target.window, observer: observer, overlay: AlwaysOnTopBorderOverlay())
        pinnedWindows[target.key] = PinnedWindowInfo(id: target.key, appName: target.appName,
                                                     icon: target.icon, windowTitle: target.title)
        repositionOverlay(for: target.key)
        QuickToolHUD.show(icon: "pin.fill", message: FeatureStrings.alwaysOnTop(L10n.shared.language).hudPinned)
    }

    /// Called from the C observer callback (on the main run loop).
    func handleAX(observer: AXObserver, notification: String) {
        guard let key = records.first(where: { CFEqual($0.value.observer, observer) })?.key else { return }
        if notification == (kAXUIElementDestroyedNotification as String) {
            unpin(key)
            return
        }
        if notification == (kAXWindowMovedNotification as String)
            || notification == (kAXWindowResizedNotification as String) {
            repositionOverlay(for: key)
        }
    }

    private func repositionOverlay(for key: AlwaysOnTopWindowKey) {
        guard let record = records[key],
              let origin = Self.pointAttribute(record.window, kAXPositionAttribute as String),
              let size = Self.sizeAttribute(record.window, kAXSizeAttribute as String) else { return }
        let frame = AlwaysOnTopSupport.appKitFrame(fromAXOrigin: origin, size: size,
                                                   screenTopY: Self.menuBarScreenTopY)
        record.overlay.move(to: frame)
    }

    // MARK: - Focused window resolution

    private func resolveFocusedWindow() -> FocusedWindowTarget? {
        guard let app = NSWorkspace.shared.frontmostApplication,
              app.processIdentifier != getpid() else { return nil }
        let pid = app.processIdentifier
        let appElement = AXUIElementCreateApplication(pid)
        AXUIElementSetMessagingTimeout(appElement, 0.35)

        var windowValue: CFTypeRef?
        guard AXUIElementCopyAttributeValue(appElement, kAXFocusedWindowAttribute as CFString, &windowValue) == .success,
              let windowValue, CFGetTypeID(windowValue) == AXUIElementGetTypeID() else { return nil }
        let window = (windowValue as! AXUIElement)
        AXUIElementSetMessagingTimeout(window, 0.35)
        guard let windowID = AXWindowResolver.windowID(for: window) else { return nil }

        var titleValue: CFTypeRef?
        let title = AXUIElementCopyAttributeValue(window, kAXTitleAttribute as CFString, &titleValue) == .success
            ? (titleValue as? String ?? "")
            : ""

        return FocusedWindowTarget(key: AlwaysOnTopWindowKey(pid: pid, windowID: windowID),
                                   window: window,
                                   appName: app.localizedName ?? "",
                                   icon: app.icon ?? NSWorkspace.shared.icon(forFile: "/"),
                                   title: title)
    }

    private static func pointAttribute(_ element: AXUIElement, _ attribute: String) -> CGPoint? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success,
              let value, CFGetTypeID(value) == AXValueGetTypeID() else { return nil }
        let axValue = value as! AXValue
        guard AXValueGetType(axValue) == .cgPoint else { return nil }
        var point = CGPoint.zero
        guard AXValueGetValue(axValue, .cgPoint, &point) else { return nil }
        return point
    }

    private static func sizeAttribute(_ element: AXUIElement, _ attribute: String) -> CGSize? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success,
              let value, CFGetTypeID(value) == AXValueGetTypeID() else { return nil }
        let axValue = value as! AXValue
        guard AXValueGetType(axValue) == .cgSize else { return nil }
        var size = CGSize.zero
        guard AXValueGetValue(axValue, .cgSize, &size) else { return nil }
        return size
    }

    /// The screen holding the menu bar, whose top edge is Accessibility's
    /// y-origin. Mirrors `WindowLayoutService.menuBarScreenTopY`; duplicated
    /// rather than shared so this feature never has to touch that file.
    private static var menuBarScreenTopY: CGFloat {
        let menuBarScreen = NSScreen.screens.first {
            abs($0.frame.minX) < 0.5 && abs($0.frame.minY) < 0.5
        }
        return (menuBarScreen ?? NSScreen.main ?? NSScreen.screens.first)?.frame.maxY ?? 0
    }

    // MARK: - Private window-level API

    private typealias CGSConnectionID = Int32
    private typealias CGSMainConnectionIDFunc = @convention(c) () -> CGSConnectionID
    private typealias CGSSetWindowLevelFunc = @convention(c) (CGSConnectionID, CGWindowID, Int32) -> Int32

    private static let pinnedLevel = CGWindowLevelForKey(.floatingWindow)

    /// SkyLight's window-level setter, resolved once like the dark-mode switch
    /// in `QuickTogglesService`: a missing symbol just means pinning silently
    /// does nothing rather than crashing.
    private static let windowLevelFunctions: (mainConnectionID: CGSMainConnectionIDFunc,
                                              setWindowLevel: CGSSetWindowLevelFunc)? = {
        let path = "/System/Library/PrivateFrameworks/SkyLight.framework/SkyLight"
        guard let handle = dlopen(path, RTLD_LAZY),
              let mainConnectionSymbol = dlsym(handle, "CGSMainConnectionID"),
              let setLevelSymbol = dlsym(handle, "CGSSetWindowLevel") else { return nil }
        return (unsafeBitCast(mainConnectionSymbol, to: CGSMainConnectionIDFunc.self),
                unsafeBitCast(setLevelSymbol, to: CGSSetWindowLevelFunc.self))
    }()

    @discardableResult
    private static func setWindowLevel(_ window: AXUIElement, level: CGWindowLevel) -> Bool {
        guard let windowID = AXWindowResolver.windowID(for: window),
              let functions = windowLevelFunctions else { return false }
        let connection = functions.mainConnectionID()
        return functions.setWindowLevel(connection, windowID, level) == 0
    }
}

/// C trampoline for AXObserver — no captures, so it bridges to a C function
/// pointer; the service is recovered from the refcon.
private func alwaysOnTopAXCallback(_ observer: AXObserver,
                                   _ element: AXUIElement,
                                   _ notification: CFString,
                                   _ refcon: UnsafeMutableRawPointer?) {
    guard let refcon else { return }
    let service = Unmanaged<AlwaysOnTopService>.fromOpaque(refcon).takeUnretainedValue()
    service.handleAX(observer: observer, notification: notification as String)
}
