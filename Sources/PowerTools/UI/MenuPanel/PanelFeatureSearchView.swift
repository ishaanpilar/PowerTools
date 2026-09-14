// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint
// Copyright (C) 2026 PowerTools contributors

import SwiftUI

/// The field that stands where a section's back row would, while the panel
/// searches its features. Arrows move the selection, Return opens it and
/// Escape leaves search.
struct PanelSearchField: View {
    @Binding var query: String
    /// Bumped by every request to search, so a shortcut pressed while the
    /// field is already on screen still puts the caret back in it.
    let focusToken: Int
    let onMove: (Int) -> Void
    let onSubmit: () -> Void
    let onClose: () -> Void

    @ObservedObject private var l10n = L10n.shared
    @Environment(\.colorScheme) private var colorScheme
    @FocusState private var isFocused: Bool

    var body: some View {
        let strings = FeatureStrings.panelSearch(l10n.language)
        HStack(spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
                TextField(strings.placeholder, text: $query)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13))
                    .focused($isFocused)
                    .onSubmit(onSubmit)
                    .onKeyPress(.downArrow) { onMove(1); return .handled }
                    .onKeyPress(.upArrow) { onMove(-1); return .handled }
                    .onKeyPress(.escape) { onClose(); return .handled }
            }
            .padding(.horizontal, 9)
            .frame(height: 30)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(PanelSurface.cardFill(for: colorScheme))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(isFocused ? Color.accentColor.opacity(0.6)
                                            : PanelSurface.border(for: colorScheme),
                                  lineWidth: isFocused ? 1 : 0.7)
            )

            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .semibold))
                    .frame(width: 26, height: 26)
                    .contentShape(Circle())
                    .panelGlassControl(in: Circle())
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .help(strings.closeSearch)
            .accessibilityLabel(strings.closeSearch)
        }
        .onAppear(perform: requestFocus)
        .onChange(of: focusToken) { _, _ in requestFocus() }
    }

    /// Deferred one turn: the popover becomes key only after it presents, and
    /// focus asked for before that is silently dropped.
    private func requestFocus() {
        DispatchQueue.main.async { isFocused = true }
    }
}

/// The ranked features, grouped by where they open. Replaces the dashboard
/// for as long as the panel is searching.
struct PanelSearchResultsList: View {
    let results: PanelSearchResults
    let query: String
    let selection: AppFeature?
    let onOpen: (AppFeature) -> Void

    @ObservedObject private var l10n = L10n.shared
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let strings = FeatureStrings.panelSearch(l10n.language)
        VStack(alignment: .leading, spacing: 12) {
            if results.isEmpty {
                Text(String(format: strings.noResultsFormat,
                            query.trimmingCharacters(in: .whitespacesAndNewlines)))
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
            }
            group(strings.opensInPanel, results.opensInPanel)
            group(strings.opensSeparately, results.opensSeparately)
            group(strings.notInstalledSection, results.notInstalled)
        }
    }

    @ViewBuilder
    private func group(_ title: String, _ features: [AppFeature]) -> some View {
        if !features.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                sectionTitle(title)
                    .padding(.leading, 2)
                    .accessibilityAddTraits(.isHeader)
                VStack(spacing: 2) {
                    ForEach(features, id: \.self) { feature in
                        PanelSearchRow(feature: feature,
                                       isSelected: selection == feature,
                                       onOpen: { onOpen(feature) })
                    }
                }
                .padding(4)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(PanelSurface.cardFill(for: colorScheme))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(PanelSurface.border(for: colorScheme), lineWidth: 0.7)
                )
            }
        }
    }
}

private struct PanelSearchRow: View {
    let feature: AppFeature
    let isSelected: Bool
    let onOpen: () -> Void

    @ObservedObject private var l10n = L10n.shared
    @ObservedObject private var features = FeatureRuntime.shared
    @State private var isHovering = false
    @State private var isInstalling = false

    var body: some View {
        let strings = FeatureStrings.panelSearch(l10n.language)
        let hub = FeatureStrings.hub(l10n.language)
        let installed = feature.isAvailable
        let title = feature.hubTitle(l10n.s, hub: hub)
        HStack(spacing: 6) {
            // The row and the Install button are siblings, never nested: a
            // button inside another loses its clicks to the outer one.
            Button(action: onOpen) {
                HStack(spacing: 9) {
                    Image(systemName: feature.symbolName)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(installed ? Color.accentColor : Color.secondary)
                        .frame(width: 26, height: 26)
                        .background(
                            RoundedRectangle(cornerRadius: 7, style: .continuous)
                                .fill((installed ? Color.accentColor : Color.secondary).opacity(0.13))
                        )
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(title)
                            .font(.system(size: 12.5, weight: .medium))
                            .foregroundStyle(installed ? Color.primary : Color.secondary)
                            .lineLimit(1)
                        Text(CommandBarCatalog.groupTitle(feature.group, hub: hub))
                            .font(.system(size: 10.5))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    Spacer(minLength: 6)
                    if installed {
                        Image(systemName: feature.panelSearchDestination.opensInPanel
                              ? "chevron.right" : "arrow.up.forward")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(.tertiary)
                            .accessibilityHidden(true)
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityHint(installed
                ? (feature.panelSearchDestination.opensInPanel
                   ? strings.opensInPanel : strings.opensSeparately)
                : strings.showInFeatures)

            if !installed {
                installControl(hub: hub, title: title)
            }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 5)
        .background(
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(highlight)
        )
        .onHover { isHovering = $0 }
    }

    /// The same install the Features page performs, with its short beat of
    /// progress; the row then moves up into its installed group.
    @ViewBuilder
    private func installControl(hub: FeatureHubStrings, title: String) -> some View {
        if isInstalling {
            ProgressView()
                .controlSize(.small)
                .frame(width: 44)
        } else if let reason = feature.installBlockedReason {
            // .help() never fires on a disabled control, so it sits on this
            // wrapper, as on the Features page.
            HStack(spacing: 0) {
                Button(hub.installButton) {}
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .disabled(true)
                    .accessibilityLabel("\(hub.installButton) \(title). \(reason)")
            }
            .help(reason)
        } else {
            Button(hub.installButton, action: install)
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .accessibilityLabel("\(hub.installButton) \(title)")
        }
    }

    private func install() {
        guard !isInstalling else { return }
        isInstalling = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
            withAnimation(.easeOut(duration: 0.22)) {
                FeatureRuntime.shared.setAvailable(feature, true)
            }
            isInstalling = false
        }
    }

    private var highlight: Color {
        if isSelected { return Color.accentColor.opacity(0.16) }
        if isHovering { return Color.primary.opacity(0.06) }
        return .clear
    }
}
