// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint
// Copyright (C) 2026 PowerTools contributors

import CoreGraphics
import Foundation

/// Identifies one pinned window across Accessibility notifications. The
/// WindowServer reuses a `CGWindowID` once its window closes, so the id alone
/// cannot tell a stale notification from a live one; pairing it with the
/// owning pid makes a notification for a since-closed, id-recycled window
/// harmless to ignore.
struct AlwaysOnTopWindowKey: Hashable {
    let pid: pid_t
    let windowID: CGWindowID
}

enum AlwaysOnTopSupport {
    /// Converts an Accessibility window frame (origin at the top-left of the
    /// screen holding the menu bar, y growing downward) to the AppKit frame
    /// (origin at that screen's bottom-left, y growing upward) the border
    /// overlay window is positioned with. `screenTopY` is that screen's
    /// `NSScreen.frame.maxY`.
    static func appKitFrame(fromAXOrigin axOrigin: CGPoint,
                            size: CGSize,
                            screenTopY: CGFloat) -> CGRect {
        CGRect(x: axOrigin.x,
              y: screenTopY - axOrigin.y - size.height,
              width: size.width,
              height: size.height)
    }
}
