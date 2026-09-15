// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 PowerTools AI contributors

import Foundation

/// Builds an `AIContextManifest` for each kind of content text actions can
/// send. One function per content type, not a generic constructor, so a new
/// content type (a clipboard item, a screenshot, a file - named in
/// PRIVACY.md as future sources) adds a function instead of a stringly-typed
/// branch here.
enum AIContextManifestBuilder {
    static let selectedTextContentType = "selected-text"

    static func selectedText(
        _ text: String,
        option: AITextActionsProviderOption,
        strings: AITextActionsFeatureStrings
    ) -> AIContextManifest {
        AIContextManifest(
            contentType: selectedTextContentType,
            contentTypeLabel: strings.previewContentTypeSelectedText,
            itemCount: 1,
            approximateSizeBytes: text.utf8.count,
            boundary: option.boundary,
            providerID: option.providerID,
            providerDisplayName: AITextActionsProviderCatalog.displayName(for: option.kind, strings: strings),
            retentionNote: option.boundary == .local ? strings.previewRetentionLocal : strings.previewRetentionRemote,
            privacyURL: option.privacyURL
        )
    }
}
