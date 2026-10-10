// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 PowerTools AI contributors

import SwiftUI

/// What the last action did, shown under the actions until the next one.
enum ClaudeAccountsStatus: Equatable {
    case success(String)
    case problem(String)
    case info(String)
}

/// The actions of one host (the panel or the settings page) and their
/// outcome, shared by its rows and buttons.
final class ClaudeAccountsInteraction: ObservableObject {
    @Published var status: ClaudeAccountsStatus?
    @Published var pendingRemoval: ClaudeAccountIdentity?

    private let service = ClaudeAccountsService.shared
    private var strings: ClaudeAccountsStrings { FeatureStrings.claudeAccounts(L10n.shared.language) }

    func saveCurrent() {
        service.saveCurrent { [weak self] identity in
            guard let self else { return }
            status = identity.map { .success(String(format: self.strings.savedFormat, $0.email)) }
                ?? .problem(strings.nothingToSave)
        }
    }

    func logIn(email: String?) {
        service.logIn(email: email) { [weak self] opened in
            guard let self else { return }
            status = opened ? .info(strings.loginOpened) : .problem(strings.terminalFailed)
        }
    }

    func switchTo(_ account: ClaudeAccountIdentity) {
        service.switchTo(account.key) { [weak self] result in
            guard let self else { return }
            let message = strings.message(for: result, email: account.email)
            status = result.succeeded ? .success(message) : .problem(message)
        }
    }

    func confirmRemoval() {
        guard let account = pendingRemoval else { return }
        service.remove(account.key)
        pendingRemoval = nil
        status = nil
    }
}

struct ClaudeAccountRow: View {
    @ObservedObject private var l10n = L10n.shared
    @ObservedObject private var service = ClaudeAccountsService.shared
    let account: ClaudeAccountIdentity
    let compact: Bool
    @ObservedObject var interaction: ClaudeAccountsInteraction

    private var strings: ClaudeAccountsStrings { FeatureStrings.claudeAccounts(l10n.language) }
    private var isActive: Bool { account.key == service.activeKey }
    private var name: String { account.email.isEmpty ? account.accountID : account.email }

    var body: some View {
        HStack(spacing: compact ? 8 : 10) {
            avatar
            VStack(alignment: .leading, spacing: 1) {
                Text(name)
                    .font(.system(size: compact ? 12 : 13, weight: .medium))
                    .lineLimit(1)
                    .truncationMode(.middle)
                // The panel is too narrow for a badge beside the email, so
                // there the active state moves onto the line below it.
                if compact && isActive {
                    activeLabel
                } else if account.hasNamedOrganization {
                    Text(account.organizationName)
                        .font(.system(size: compact ? 10.5 : 11))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
            }
            Spacer(minLength: 8)
            if isActive {
                if !compact { activeBadge }
            } else {
                Button(strings.switchButton) { interaction.switchTo(account) }
                    .controlSize(compact ? .small : .regular)
                    .disabled(service.isWorking)
            }
            moreMenu
        }
        .padding(.vertical, compact ? 2 : 3)
    }

    private var avatar: some View {
        let size: CGFloat = compact ? 24 : 28
        return Circle()
            .fill(isActive ? Color.accentColor : Color.secondary.opacity(0.35))
            .frame(width: size, height: size)
            .overlay(
                Text(name.prefix(1).uppercased())
                    .font(.system(size: size * 0.45, weight: .semibold))
                    .foregroundStyle(.white)
            )
            .accessibilityHidden(true)
    }

    private var activeLabel: some View {
        Label(strings.activeBadge, systemImage: "checkmark.circle.fill")
            .labelStyle(.titleAndIcon)
            .font(.system(size: compact ? 10.5 : 11, weight: .semibold))
            .foregroundStyle(.green)
    }

    private var activeBadge: some View {
        activeLabel
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(Capsule().fill(Color.green.opacity(0.14)))
    }

    private var moreMenu: some View {
        Menu {
            Button(strings.logInAgainButton) { interaction.logIn(email: account.email) }
            Divider()
            // The login Claude Code is using cannot be removed; switch away first.
            Button(strings.removeButton, role: .destructive) { interaction.pendingRemoval = account }
                .disabled(isActive)
        } label: {
            Image(systemName: "ellipsis.circle")
                .font(.system(size: compact ? 13 : 15))
                .foregroundStyle(.secondary)
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
        .disabled(service.isWorking)
        .help(strings.moreActionsHelp)
        .accessibilityLabel(strings.moreActionsHelp)
    }
}

struct ClaudeAccountsEmptyRow: View {
    @ObservedObject private var l10n = L10n.shared
    let compact: Bool

    private var strings: ClaudeAccountsStrings { FeatureStrings.claudeAccounts(l10n.language) }

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: "person.crop.circle.badge.plus")
                .font(.system(size: compact ? 20 : 24))
                .foregroundStyle(.secondary)
            Text(strings.emptyTitle)
                .font(.system(size: compact ? 12 : 13, weight: .medium))
            Text(strings.emptyText)
                .font(.system(size: compact ? 10.5 : 11))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, compact ? 6 : 10)
    }
}

struct ClaudeAccountsActionBar: View {
    @ObservedObject private var l10n = L10n.shared
    @ObservedObject private var service = ClaudeAccountsService.shared
    @ObservedObject var interaction: ClaudeAccountsInteraction

    private var strings: ClaudeAccountsStrings { FeatureStrings.claudeAccounts(l10n.language) }

    var body: some View {
        HStack(spacing: 8) {
            if service.isWorking { ProgressView().controlSize(.small) }
            Spacer(minLength: 0)
            Button(strings.saveCurrentButton) { interaction.saveCurrent() }
                .disabled(service.isWorking || service.activeKey == nil)
            Button(strings.addAccountButton) { interaction.logIn(email: nil) }
                .disabled(service.isWorking)
        }
    }
}

struct ClaudeAccountsStatusLine: View {
    let status: ClaudeAccountsStatus
    var compact = false

    var body: some View {
        let (text, symbol, color): (String, String, Color) = {
            switch status {
            case .success(let text): return (text, "checkmark.circle.fill", .green)
            case .problem(let text): return (text, "exclamationmark.triangle.fill", .orange)
            case .info(let text): return (text, "info.circle.fill", .blue)
            }
        }()
        return Label {
            Text(text)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
        } icon: {
            Image(systemName: symbol).foregroundStyle(color)
        }
        .font(.system(size: compact ? 10.5 : 12))
    }
}

/// Refreshes the list when it appears and asks before a saved login is
/// removed; shared by both hosts so neither can skip the confirmation.
private struct ClaudeAccountsLifecycle: ViewModifier {
    @ObservedObject private var l10n = L10n.shared
    @ObservedObject var interaction: ClaudeAccountsInteraction

    private var strings: ClaudeAccountsStrings { FeatureStrings.claudeAccounts(l10n.language) }

    func body(content: Content) -> some View {
        content
            .onAppear { ClaudeAccountsService.shared.refresh() }
            .confirmationDialog(String(format: strings.removeConfirmTitleFormat,
                                       interaction.pendingRemoval?.email ?? ""),
                                isPresented: Binding(get: { interaction.pendingRemoval != nil },
                                                     set: { if !$0 { interaction.pendingRemoval = nil } }),
                                titleVisibility: .visible) {
                Button(strings.removeConfirmAction, role: .destructive) { interaction.confirmRemoval() }
                Button(l10n.s.uninstallerCancel, role: .cancel) {}
            } message: {
                Text(strings.removeConfirmMessage)
            }
    }
}

struct PanelClaudeAccountsView: View {
    @ObservedObject private var l10n = L10n.shared
    @ObservedObject private var service = ClaudeAccountsService.shared
    @StateObject private var interaction = ClaudeAccountsInteraction()
    var onClose: () -> Void

    private var strings: ClaudeAccountsStrings { FeatureStrings.claudeAccounts(l10n.language) }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Label(strings.title, systemImage: AppFeature.claudeAccounts.symbolName)
                    .font(.system(size: 12, weight: .semibold))
                Spacer()
                Button(action: onClose) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                        .frame(width: 22, height: 22)
                }
                .buttonStyle(.plain)
                .help(l10n.s.uninstallerCancel)
            }

            VStack(alignment: .leading, spacing: 6) {
                if service.accounts.isEmpty {
                    ClaudeAccountsEmptyRow(compact: true)
                } else {
                    ForEach(Array(service.accounts.enumerated()), id: \.element.key) { index, account in
                        if index > 0 { Divider() }
                        ClaudeAccountRow(account: account, compact: true, interaction: interaction)
                    }
                }
            }
            .panelCard()

            VStack(alignment: .leading, spacing: 8) {
                ClaudeAccountsActionBar(interaction: interaction)
                    .controlSize(.small)
                if let status = interaction.status {
                    ClaudeAccountsStatusLine(status: status, compact: true)
                }
                Text(strings.panelFootnote)
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
            }
        }
        .modifier(ClaudeAccountsLifecycle(interaction: interaction))
        .onAppear { PanelInteractionState.shared.viewKeepsPopoverOpen = true }
        .onDisappear { PanelInteractionState.shared.viewKeepsPopoverOpen = false }
    }
}

struct ClaudeAccountsSettings: View {
    @ObservedObject private var l10n = L10n.shared
    @ObservedObject private var service = ClaudeAccountsService.shared
    @StateObject private var interaction = ClaudeAccountsInteraction()

    private var strings: ClaudeAccountsStrings { FeatureStrings.claudeAccounts(l10n.language) }

    var body: some View {
        Form {
            Section {
                if service.accounts.isEmpty {
                    ClaudeAccountsEmptyRow(compact: false)
                } else {
                    ForEach(service.accounts, id: \.key) { account in
                        ClaudeAccountRow(account: account, compact: false, interaction: interaction)
                    }
                }
            } header: {
                Text(strings.accountsSectionTitle)
            } footer: {
                footer(strings.accountsFooter)
            }

            Section {
                ClaudeAccountsActionBar(interaction: interaction)
                if let status = interaction.status {
                    ClaudeAccountsStatusLine(status: status)
                }
            } header: {
                Text(strings.addSectionTitle)
            } footer: {
                footer(strings.addFooter)
            }
        }
        .formStyle(.grouped)
        .modifier(ClaudeAccountsLifecycle(interaction: interaction))
    }

    private func footer(_ text: String) -> some View {
        Text(text)
            .font(.caption)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
    }
}
