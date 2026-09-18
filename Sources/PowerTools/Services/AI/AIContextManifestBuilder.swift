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
    static let healthSnapshotContentType = "health-snapshot"

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

    /// Health Coach's Explain (`docs/ai-health-coach/README.md` section
    /// 3.4): `findingCount` findings plus the journal summary the prompt
    /// builder folds in, never a window title, a file path or clipboard
    /// content. `contentTypeLabel`/`retentionNote` come from
    /// `HealthCoachStrings`, not `AITextActionsFeatureStrings` — a Mac
    /// health snapshot is not selected text, and the shared preview sheet
    /// only needs plain label strings, not a feature-specific string type.
    static func healthSnapshot(
        findingCount: Int,
        approximateSizeBytes: Int,
        option: AITextActionsProviderOption,
        contentTypeLabel: String,
        retentionLocal: String,
        retentionRemote: String,
        providerDisplayName: String
    ) -> AIContextManifest {
        AIContextManifest(
            contentType: healthSnapshotContentType,
            contentTypeLabel: contentTypeLabel,
            itemCount: findingCount,
            approximateSizeBytes: approximateSizeBytes,
            boundary: option.boundary,
            providerID: option.providerID,
            providerDisplayName: providerDisplayName,
            retentionNote: option.boundary == .local ? retentionLocal : retentionRemote,
            privacyURL: option.privacyURL
        )
    }
}
