// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 PowerTools AI contributors

import Foundation

/// Whether the header's findings-and-journal detail is expanded in place,
/// shared between the header (which toggles it) and the panel content
/// (which renders it) — the same "expand in place" shape the dashboard
/// cards already use, rather than a second `NSPopover` nested inside the
/// menu bar's own (nesting SwiftUI's `.popover` inside an already
/// `NSPopover`-hosted tree is not a pattern used anywhere else in this app).
final class HealthCoachDetailPresentation: ObservableObject {
    static let shared = HealthCoachDetailPresentation()

    @Published var isExpanded = false

    private init() {}

    func toggle() {
        isExpanded.toggle()
    }

    func collapse() {
        isExpanded = false
    }
}
