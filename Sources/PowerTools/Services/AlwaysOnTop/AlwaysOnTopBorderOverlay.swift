// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint
// Copyright (C) 2026 PowerTools contributors

import AppKit

/// A borderless, click-through window that outlines one pinned window and
/// tracks its live frame. Shaped like `DockPreviewDragGhost`: an all-Spaces
/// overlay that never receives the clicks meant for the real window beneath
/// it. Main thread only, like the service that owns it.
final class AlwaysOnTopBorderOverlay {
    private var window: NSWindow?

    private static let borderWidth: CGFloat = 3
    private static let borderColor = NSColor.controlAccentColor

    func move(to frame: CGRect) {
        guard frame.width > 0, frame.height > 0 else { end(); return }
        if window == nil {
            let panel = NSWindow(contentRect: frame, styleMask: [.borderless],
                                 backing: .buffered, defer: false)
            panel.backgroundColor = .clear
            panel.isOpaque = false
            panel.hasShadow = false
            panel.level = .floating
            panel.ignoresMouseEvents = true
            panel.animationBehavior = .none
            panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient, .ignoresCycle]
            panel.contentView = BorderView(frame: CGRect(origin: .zero, size: frame.size))
            window = panel
            panel.orderFrontRegardless()
        }
        window?.setFrame(frame, display: true)
    }

    func end() {
        window?.orderOut(nil)
        window = nil
    }

    private final class BorderView: NSView {
        override var isOpaque: Bool { false }

        override func draw(_ dirtyRect: NSRect) {
            let inset = AlwaysOnTopBorderOverlay.borderWidth / 2
            let path = NSBezierPath(roundedRect: bounds.insetBy(dx: inset, dy: inset), xRadius: 6, yRadius: 6)
            path.lineWidth = AlwaysOnTopBorderOverlay.borderWidth
            AlwaysOnTopBorderOverlay.borderColor.setStroke()
            path.stroke()
        }
    }
}
