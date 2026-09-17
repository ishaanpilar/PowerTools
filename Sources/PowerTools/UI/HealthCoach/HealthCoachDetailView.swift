// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 PowerTools AI contributors

import SwiftUI

/// The header's status line, tapped: current findings with evidence chips
/// that jump to the matching dashboard card, and the activity journal.
/// Expands in place, the same shape the dashboard's own cards already use
/// (see `HealthCoachDetailPresentation`). No AI here — that is a later task.
struct HealthCoachDetailView: View {
    @ObservedObject private var l10n = L10n.shared
    @ObservedObject private var journalService = HealthActivityJournalService.shared

    private var strings: HealthCoachStrings { FeatureStrings.healthCoach(l10n.language) }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            findingsSection
            Divider()
            journalSection
        }
        .padding(.vertical, 6)
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
