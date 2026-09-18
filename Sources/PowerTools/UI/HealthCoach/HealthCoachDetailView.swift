// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 PowerTools AI contributors

import SwiftUI

/// The header's status line, tapped: current findings with evidence chips
/// that jump to the matching dashboard card, and the activity journal.
/// Expands in place, the same shape the dashboard's own cards already use
/// (see `HealthCoachDetailPresentation`). Also where an AI explanation's
/// detail bullets, the pre-send preview and "Explain again" show up
/// (task 07) — the header only ever has room for the one-line headline.
struct HealthCoachDetailView: View {
    @ObservedObject private var l10n = L10n.shared
    @ObservedObject private var journalService = HealthActivityJournalService.shared
    @ObservedObject private var narrator = HealthNarratorService.shared
    @ObservedObject private var monitor = SystemMonitor.shared

    private var strings: HealthCoachStrings { FeatureStrings.healthCoach(l10n.language) }

    private var findings: [HealthFinding] { journalService.latestFindings.orderedByUrgency }

    /// Matches `MenuPanelHeader.activeNarration`: only shown while it still
    /// answers the findings actually on screen.
    private var activeNarration: HealthNarration? {
        guard let current = narrator.current, !findings.isEmpty,
              current.findingKinds == Set(findings.map(\.kind)) else { return nil }
        return current
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            collapseRow
            if let pendingPreview = narrator.pendingPreview {
                AIPreSendPreviewSheet(
                    manifest: pendingPreview,
                    onSend: { narrator.confirmPendingPreview() },
                    onCancel: { narrator.cancelPendingPreview() },
                    width: 300
                )
            }
            if let activeNarration {
                narrationSection(activeNarration)
                Divider()
            }
            findingsSection
            Divider()
            journalSection
        }
        .padding(.vertical, 6)
    }

    private func narrationSection(_ narration: HealthNarration) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(Array(narration.bullets.enumerated()), id: \.offset) { _, bullet in
                Text("•  \(bullet)")
                    .font(.system(size: 11.5))
                    .fixedSize(horizontal: false, vertical: true)
            }
            HStack(spacing: 8) {
                Text(String(format: strings.narratorExplainedFormat,
                           Self.relativeFormatter.localizedString(for: narration.generatedAt, relativeTo: Date()),
                           narration.providerBoundary == .local
                               ? strings.narratorSourceOnDevice
                               : AITextActionsProviderCatalog.displayName(
                                   for: AITextActionsProviderConfiguration.current().kind,
                                   strings: FeatureStrings.aiTextActions(l10n.language))))
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                Spacer(minLength: 4)
                if narrator.isStreaming {
                    Button(strings.narratorCancelButton) { narrator.cancelStreaming() }
                        .buttonStyle(.plain)
                        .font(.system(size: 10.5))
                        .foregroundStyle(.secondary)
                } else {
                    Button(strings.narratorExplainAgainButton) {
                        narrator.explain(trigger: .explainPressed, findings: findings,
                                         journal: journalService.journal,
                                         settings: .sanitized(defaults: .standard),
                                         system: .current(thermalPressure: monitor.snapshot.thermalPressure,
                                                          memoryPressure: monitor.snapshot.memoryPressure))
                    }
                    .buttonStyle(.plain)
                    .font(.system(size: 10.5))
                    .foregroundStyle(.secondary)
                }
            }
        }
    }

    /// A close control that lives with the content it closes, not only back
    /// at the header row that opened it: the header's own toggle can scroll
    /// or resize out of easy reach once this view is showing several
    /// findings and journal entries, and a person looking at this content
    /// should not have to go hunting for where they tapped to get here.
    private var collapseRow: some View {
        HStack {
            Spacer()
            Button {
                HealthCoachDetailPresentation.shared.collapse()
            } label: {
                Image(systemName: "chevron.up.circle.fill")
                    .font(.system(size: 13))
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .accessibilityLabel(strings.detailCollapseButton)
        }
    }

    private var findingsSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(strings.detailFindingsSectionTitle)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
            let findings = journalService.latestFindings.orderedByUrgency
            if findings.isEmpty {
                Text(strings.detailNoFindingsText)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            } else {
                ForEach(Array(findings.enumerated()), id: \.offset) { _, finding in
                    findingRow(finding)
                }
            }
        }
    }

    private func findingRow(_ finding: HealthFinding) -> some View {
        HStack(alignment: .top, spacing: 6) {
            Circle()
                .fill(severityColor(finding.severity))
                .frame(width: 6, height: 6)
                .padding(.top, 4)
            Text(HealthNarrationTemplate.headline(for: finding, strings: l10n.s, healthCoach: strings))
                .font(.system(size: 11.5))
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 4)
            if let metric = finding.metricDetailKind {
                Button {
                    HealthCoachDetailPresentation.shared.collapse()
                    MenuPanelFocus.shared.focus(metric)
                } label: {
                    Image(systemName: "chevron.right.circle")
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
            }
        }
    }

    private var journalSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(strings.detailActivitySectionTitle)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                if !journalService.journal.entries.isEmpty {
                    Button(strings.detailClearActivity) {
                        journalService.clear()
                    }
                    .buttonStyle(.plain)
                    .font(.system(size: 10.5))
                    .foregroundStyle(.secondary)
                }
            }
            if journalService.journal.entries.isEmpty {
                Text(strings.detailJournalEmptyText)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            } else {
                ForEach(journalService.journal.entries.prefix(8), id: \.occurredAt) { entry in
                    journalRow(entry)
                }
            }
        }
    }

    private func journalRow(_ entry: HealthActivityJournalEntry) -> some View {
        HStack(spacing: 6) {
            Text(HealthJournalTemplate.text(for: entry.event, strings: strings))
                .font(.system(size: 11))
            Spacer(minLength: 4)
            Text(Self.relativeFormatter.localizedString(for: entry.occurredAt, relativeTo: Date()))
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
        }
    }

    private func severityColor(_ severity: HealthFinding.Severity) -> Color {
        switch severity {
        case .critical: return .red
        case .notable: return .orange
        case .info: return .secondary
        }
    }

    private static let relativeFormatter: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        formatter.dateTimeStyle = .named
        return formatter
    }()
}
