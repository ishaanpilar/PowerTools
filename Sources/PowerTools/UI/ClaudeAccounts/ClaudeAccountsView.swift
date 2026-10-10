// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 PowerTools AI contributors

import SwiftUI

/// The saved Claude Code logins and their actions. The panel hosts it with a
/// close button; Settings hosts it inside its own form.
struct ClaudeAccountsList: View {
    @ObservedObject private var l10n = L10n.shared
    @ObservedObject private var service = ClaudeAccountsService.shared
    @State private var message: String?
    @State private var pendingRemoval: ClaudeAccountIdentity?

    private var strings: ClaudeAccountsStrings { FeatureStrings.claudeAccounts(l10n.language) }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if service.accounts.isEmpty {
                caption(strings.emptyText)
            } else {
                ForEach(service.accounts, id: \.key, content: row)
            }
            HStack(spacing: 7) {
                Button(strings.saveCurrentButton, action: saveCurrent)
                    .disabled(service.isWorking || service.activeKey == nil)
                Spacer()
                if service.isWorking { ProgressView().controlSize(.small) }
            }
            .controlSize(.small)
            if let message { caption(message) }
            caption(strings.addAccountHint)
            caption(strings.intro)
        }
        .onAppear { service.refresh() }
        .confirmationDialog(String(format: strings.removeConfirmTitleFormat, pendingRemoval?.email ?? ""),
                            isPresented: Binding(get: { pendingRemoval != nil },
                                                 set: { if !$0 { pendingRemoval = nil } }),
                            titleVisibility: .visible,
                            presenting: pendingRemoval) { account in
            Button(strings.removeConfirmAction, role: .destructive) {
                service.remove(account.key)
                message = nil
            }
            Button(l10n.s.uninstallerCancel, role: .cancel) {}
        } message: { _ in
            Text(strings.removeConfirmMessage)
        }
    }

    private func row(_ account: ClaudeAccountIdentity) -> some View {
        let isActive = account.key == service.activeKey
        return HStack(spacing: 8) {
            Image(systemName: isActive ? "person.crop.circle.fill.badge.checkmark" : "person.crop.circle")
                .font(.system(size: 15))
                .foregroundStyle(isActive ? Color.accentColor : Color.secondary)
            VStack(alignment: .leading, spacing: 1) {
                Text(account.email.isEmpty ? account.accountID : account.email)
                    .font(.system(size: 11.5, weight: .medium))
                    .lineLimit(1)
                    .truncationMode(.middle)
                if !account.organizationName.isEmpty {
                    Text(account.organizationName)
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 4)
            if isActive {
                Text(strings.activeBadge)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.secondary)
            } else {
                Button(strings.switchButton) { switchTo(account) }
                    .controlSize(.small)
                    .disabled(service.isWorking)
            }
            // Kept apart from Switch, and disabled for the active login, so a
            // slip never removes the login Claude Code is using.
            Button {
                pendingRemoval = account
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 11))
                    .frame(width: 20, height: 20)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .help(strings.removeHelp)
            .accessibilityLabel(strings.removeHelp)
            .disabled(service.isWorking || isActive)
        }
    }

    private func caption(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 10.5))
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
    }

    private func saveCurrent() {
        service.saveCurrent { identity in
            message = identity.map { String(format: strings.savedFormat, $0.email) } ?? strings.nothingToSave
        }
    }

    private func switchTo(_ account: ClaudeAccountIdentity) {
        service.switchTo(account.key) { result in
            message = strings.message(for: result, email: account.email)
        }
    }
}

struct PanelClaudeAccountsView: View {
    @ObservedObject private var l10n = L10n.shared
    var onClose: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Label(FeatureStrings.claudeAccounts(l10n.language).title,
                      systemImage: AppFeature.claudeAccounts.symbolName)
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
            ClaudeAccountsList()
                .panelCard()
        }
        .onAppear { PanelInteractionState.shared.viewKeepsPopoverOpen = true }
        .onDisappear { PanelInteractionState.shared.viewKeepsPopoverOpen = false }
    }
}

struct ClaudeAccountsSettings: View {
    var body: some View {
        Form {
            Section {
                ClaudeAccountsList()
            }
        }
    }
}
