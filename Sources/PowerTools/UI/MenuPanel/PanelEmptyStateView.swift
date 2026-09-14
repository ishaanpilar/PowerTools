// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint
// Copyright (C) 2026 PowerTools contributors

import SwiftUI

/// What the dashboard shows instead of blank space when it has nothing to
/// draw: a way into setup when nothing is installed, back to the panel
/// layout when installed sections are hidden, or to the Features page when
/// only background features are installed.
struct PanelDashboardEmptyState: View {
    @ObservedObject private var l10n = L10n.shared
    @ObservedObject private var features = FeatureRuntime.shared
    @Environment(\.colorScheme) private var colorScheme

    /// Why the dashboard is empty decides what it offers.
    private enum Reason {
        /// Nothing is installed: setup is the way in.
        case nothingInstalled
        /// Sections are installed but switched off in the panel layout.
        case sectionsHidden
        /// Only background features are installed; none has a panel section.
        case backgroundOnly
    }

    private var reason: Reason {
        _ = features.revision
        guard AppFeature.allCases.contains(where: \.isAvailable) else { return .nothingInstalled }
        return PanelSectionID.allCases.contains(where: \.isAvailable) ? .sectionsHidden : .backgroundOnly
    }

    var body: some View {
        let strings = FeatureStrings.panelEmptyState(l10n.language)
        let reason = reason
        VStack(spacing: 14) {
            Image(systemName: reason == .nothingInstalled ? "square.grid.2x2" : "eye.slash")
                .font(.system(size: 22, weight: .medium))
                .foregroundStyle(Color.accentColor)
                .frame(width: 48, height: 48)
                .background(Circle().fill(Color.accentColor.opacity(0.13)))
                .accessibilityHidden(true)

            VStack(spacing: 4) {
                Text(reason == .nothingInstalled ? strings.noFeaturesTitle : strings.hiddenTitle)
                    .font(.system(size: 14, weight: .semibold))
                    .accessibilityAddTraits(.isHeader)
                Text(message(for: reason, strings))
                    .font(.system(size: 11.5))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .multilineTextAlignment(.center)

            VStack(spacing: 6) {
                switch reason {
                case .nothingInstalled:
                    wideButton(strings.runSetup, prominent: true) {
                        appDelegate()?.showOnboarding()
                    }
                    wideButton(strings.browseFeatures, prominent: false, action: openFeatures)
                case .sectionsHidden:
                    wideButton(strings.chooseSections, prominent: true) {
                        openSettings(FeatureSettingsDestination(.general, sectionAnchor: .panelConfiguration))
                    }
                    wideButton(strings.browseFeatures, prominent: false, action: openFeatures)
                case .backgroundOnly:
                    wideButton(strings.browseFeatures, prominent: true, action: openFeatures)
                }
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 22)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(PanelSurface.cardFill(for: colorScheme))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(PanelSurface.border(for: colorScheme), lineWidth: 0.7)
        )
    }

    private func message(for reason: Reason, _ strings: PanelEmptyStateStrings) -> String {
        switch reason {
        case .nothingInstalled: return strings.noFeaturesBody
        case .sectionsHidden: return strings.hiddenBody
        case .backgroundOnly: return strings.backgroundBody
        }
    }

    @ViewBuilder
    private func wideButton(_ title: String, prominent: Bool,
                            action: @escaping () -> Void) -> some View {
        let button = Button(action: action) {
            Text(title).frame(maxWidth: .infinity)
        }
        .controlSize(.large)
        if prominent {
            button.buttonStyle(.borderedProminent)
        } else {
            button.buttonStyle(.bordered)
        }
    }

    private func openFeatures() {
        openSettings(FeatureSettingsDestination(.features))
    }

    private func openSettings(_ destination: FeatureSettingsDestination) {
        SettingsRouter.shared.request(destination)
        appDelegate()?.closePopover()
        appDelegate()?.openSettingsWindow()
    }
}
