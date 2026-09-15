// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 PowerTools AI contributors

import SwiftUI

/// Shows exactly what an AI request is about to send, before it's sent -
/// PRIVACY.md's "Before the first request that sends a kind of content...
/// shows exactly what will be sent and to which provider". A feature shows
/// this only when `AIPreSendPreviewTracker.hasShownPreview` is false for its
/// content type and provider, and calls `AIPreSendPreviewTracker.recordPreviewShown`
/// only if the person taps Send - declining leaves it unrecorded, so the
/// preview appears again next time rather than being silently skipped.
struct AIPreSendPreviewSheet: View {
    let manifest: AIContextManifest
    let onSend: () -> Void
    let onCancel: () -> Void

    @ObservedObject private var l10n = L10n.shared
    private var strings: AITextActionsFeatureStrings { FeatureStrings.aiTextActions(l10n.language) }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(strings.previewTitle)
                .font(.title3.weight(.semibold))
            Text(strings.previewIntro)
                .font(.callout)
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 10) {
                field(strings.previewFieldContent, manifest.contentTypeLabel)
                field(strings.previewFieldItemCount, "\(manifest.itemCount)")
                field(strings.previewFieldSize, formattedSize)
                field(strings.previewFieldDestination, manifest.providerDisplayName)
                field(strings.previewFieldRetention, manifest.retentionNote)
            }
            .padding(12)
            .background(.quaternary.opacity(0.3), in: RoundedRectangle(cornerRadius: 8))

            Link(strings.privacyPolicyLink, destination: manifest.privacyURL)
                .font(.caption)

            Text(strings.previewDontAskAgainNote)
                .font(.caption2)
                .foregroundStyle(.tertiary)

            HStack {
                Spacer()
                Button(strings.previewCancelButton) { onCancel() }
                    .keyboardShortcut(.cancelAction)
                Button(strings.previewSendButton) { onSend() }
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(.borderedProminent)
            }
        }
        .padding(20)
        .frame(width: 380)
    }

    private func field(_ label: String, _ value: String) -> some View {
        HStack(alignment: .top) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 90, alignment: .leading)
            Text(value)
                .font(.caption)
                .textSelection(.enabled)
            Spacer(minLength: 0)
        }
    }

    private var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: Int64(manifest.approximateSizeBytes), countStyle: .memory)
    }
}
