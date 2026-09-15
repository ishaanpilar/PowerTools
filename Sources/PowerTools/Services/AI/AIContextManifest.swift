// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 PowerTools AI contributors

import Foundation

/// What one AI request is about to send, independent of the feature that
/// builds it: source, item count, size, whether it leaves the Mac, which
/// provider, and what happens to it afterward. Every provider request
/// carries one (`AI-HARNESS.md`'s "Arrives later" table); the pre-send
/// preview shows it verbatim, so nothing here is a summary the UI would
/// need to re-derive.
struct AIContextManifest: Equatable {
    /// Whether the request stays on this Mac or crosses the network. Not the
    /// same as "requires a key" - a local model server needs no key but is
    /// still `.local`, matching PRIVACY.md's "does not leave your Mac".
    enum Boundary: Equatable {
        case local
        case remote
    }

    /// Stable, non-localized id for "has the preview been shown for this
    /// kind of content already" - e.g. `AIContextManifestBuilder.selectedTextContentType`.
    let contentType: String
    /// Localized, human-readable label for the same content type.
    let contentTypeLabel: String
    let itemCount: Int
    let approximateSizeBytes: Int
    let boundary: Boundary
    let providerID: String
    let providerDisplayName: String
    let retentionNote: String
    let privacyURL: URL
}
