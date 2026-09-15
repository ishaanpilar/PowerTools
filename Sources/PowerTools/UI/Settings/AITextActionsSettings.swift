// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 PowerTools AI contributors

import SwiftUI

/// Settings for the AI Text Actions feature (M2): which provider to use, its
/// endpoint and model, an API key stored only in the Keychain, and a way to
/// test the connection before it's relied on. The actions themselves
/// (rewrite, shorten, proofread, summarise, translate) aren't wired into the
/// Command Bar yet - that's a later task - so this page only configures the
/// provider, and nothing here ever sends a real request except the explicit
/// Test connection button.
struct AITextActionsSettings: View {
    @ObservedObject private var l10n = L10n.shared
    private var strings: AITextActionsFeatureStrings { FeatureStrings.aiTextActions(l10n.language) }

    @AppStorage(DefaultsKey.aiTextActionsProvider) private var providerRaw = AITextActionsProviderKind.onDevice.rawValue
    @AppStorage(DefaultsKey.aiTextActionsDeepSeekModel) private var deepseekModel = ""
    @AppStorage(DefaultsKey.aiTextActionsOpenAIModel) private var openaiModel = ""
    @AppStorage(DefaultsKey.aiTextActionsAnthropicModel) private var anthropicModel = ""
    @AppStorage(DefaultsKey.aiTextActionsCustomEndpoint) private var customEndpoint = ""
    @AppStorage(DefaultsKey.aiTextActionsCustomModel) private var customModel = ""
    @AppStorage(DefaultsKey.aiTextActionsLocalEndpoint) private var localEndpoint = "http://localhost:11434/v1"
    @AppStorage(DefaultsKey.aiTextActionsLocalModel) private var localModel = ""

    @State private var apiKeyInput = ""
    @State private var hasStoredKey = false
    @State private var testState: TestState = .idle
    @State private var testTask: Task<Void, Never>?

    private enum TestState: Equatable {
        case idle
        case testing
        case success
        case failure(String)
    }

    private var kind: AITextActionsProviderKind {
        AITextActionsProviderKind(rawValue: providerRaw) ?? .onDevice
    }
    private var option: AITextActionsProviderOption { AITextActionsProviderCatalog.option(for: kind) }

    var body: some View {
        Form {
            Section {
                Text(strings.settingsIntro)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            Section(strings.providerSectionTitle) {
                Picker(strings.providerSectionTitle, selection: $providerRaw) {
                    ForEach(AITextActionsProviderCatalog.all, id: \.kind) { entry in
                        Text(displayName(for: entry.kind)).tag(entry.kind.rawValue)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .onChange(of: providerRaw) { _, _ in providerChanged() }

                availabilityRow
            }

            if option.endpointIsEditable {
                Section(strings.endpointSectionTitle) {
                    TextField(strings.endpointPlaceholder, text: endpointBinding)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(.body, design: .monospaced))
                        .onChange(of: endpointBinding.wrappedValue) { _, _ in testState = .idle }
                }
            } else if let endpoint = option.defaultEndpoint {
                Section(strings.endpointSectionTitle) {
                    Text(endpoint.absoluteString)
                        .font(.system(.body, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }
            }

            if option.modelIsEditable {
                Section(strings.modelSectionTitle) {
                    TextField(option.defaultModel ?? strings.modelPlaceholder, text: modelBinding)
                        .textFieldStyle(.roundedBorder)
                        .onChange(of: modelBinding.wrappedValue) { _, _ in testState = .idle }
                }
            }

            if option.requiresKey {
                Section(strings.apiKeySectionTitle) {
                    SecureField(hasStoredKey ? strings.apiKeyPlaceholderSaved : strings.apiKeyPlaceholderEmpty,
                                text: $apiKeyInput)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit { saveKey() }
                    HStack {
                        Button(strings.saveKeyButton) { saveKey() }
                            .disabled(apiKeyInput.isEmpty)
                        if hasStoredKey {
                            Button(strings.removeKeyButton, role: .destructive) { removeKey() }
                        }
                    }
                }
            }

            Section {
                HStack(spacing: 8) {
                    Button(strings.testConnectionButton) { runTest() }
                        .disabled(testState == .testing)
                    if testState == .testing {
                        ProgressView().controlSize(.small)
                    }
                }
                testResultView
                Link(strings.privacyPolicyLink, destination: option.privacyURL)
                    .font(.caption)
            }

            Section {
                Label(strings.comingSoonTitle, systemImage: "hourglass")
                    .font(.callout.weight(.medium))
                Text(strings.comingSoonBody)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .onAppear { refreshStoredKeyState() }
        .onDisappear { testTask?.cancel() }
    }

    // MARK: - Field bindings per provider

    private var endpointBinding: Binding<String> {
        switch kind {
        case .custom: return $customEndpoint
        case .localServer: return $localEndpoint
        default: return .constant("")
        }
    }

    private var modelBinding: Binding<String> {
        switch kind {
        case .deepseek: return $deepseekModel
        case .openai: return $openaiModel
        case .anthropic: return $anthropicModel
        case .custom: return $customModel
        case .localServer: return $localModel
        case .onDevice: return .constant("")
        }
    }

    private func displayName(for kind: AITextActionsProviderKind) -> String {
        switch kind {
        case .onDevice: return strings.providerOnDevice
        case .deepseek: return strings.providerDeepSeek
        case .openai: return strings.providerOpenAI
        case .anthropic: return strings.providerAnthropic
        case .custom: return strings.providerCustom
        case .localServer: return strings.providerLocalServer
        }
    }

    // MARK: - Key management

    private func refreshStoredKeyState() {
        guard option.requiresKey else { hasStoredKey = false; return }
        hasStoredKey = AIProviderCredentials.key(for: option.providerID) != nil
        apiKeyInput = ""
    }

    private func saveKey() {
        guard !apiKeyInput.isEmpty else { return }
        _ = AIProviderCredentials.setKey(apiKeyInput, for: option.providerID)
        apiKeyInput = ""
        hasStoredKey = true
        testState = .idle
    }

    private func removeKey() {
        _ = AIProviderCredentials.removeKey(for: option.providerID)
        hasStoredKey = false
        testState = .idle
    }

    private func providerChanged() {
        testState = .idle
        refreshStoredKeyState()
    }

    // MARK: - Test connection

    private func configuration() -> AITextActionsProviderConfiguration {
        AITextActionsProviderConfiguration(kind: kind, model: modelBinding.wrappedValue, endpoint: endpointBinding.wrappedValue)
    }

    private func runTest() {
        testTask?.cancel()
        guard let provider = AITextActionsProviderFactory.makeProvider(for: configuration()) else {
            testState = .failure(strings.reasonNoProviderConfigured)
            return
        }
        testState = .testing
        testTask = Task {
            let result = await AITextActionsProviderFactory.testConnection(provider)
            if Task.isCancelled { return }
            switch result {
            case .success:
                testState = .success
            case .failure(let error):
                testState = .failure(describe(error))
            }
        }
    }

    @ViewBuilder
    private var testResultView: some View {
        switch testState {
        case .idle, .testing:
            EmptyView()
        case .success:
            Label(strings.testConnectionSuccess, systemImage: "checkmark.circle.fill")
                .font(.caption)
                .foregroundStyle(.green)
        case .failure(let message):
            Label(message, systemImage: "exclamationmark.triangle.fill")
                .font(.caption)
                .foregroundStyle(.orange)
        }
    }

    @ViewBuilder
    private var availabilityRow: some View {
        if let availability = providerAvailability, case .unavailable(let reason) = availability {
            Label(describe(reason), systemImage: "exclamationmark.circle")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    /// nil when the kind can't even be evaluated yet (on-device on an SDK
    /// without `FoundationModels`, or custom/local with nothing typed in) -
    /// shown as nothing, since there's nothing wrong to report until the
    /// person finishes configuring it.
    private var providerAvailability: AIProviderAvailability? {
        AITextActionsProviderFactory.makeProvider(for: configuration())?.currentAvailability()
    }

    private func describe(_ reason: AIProviderUnavailableReason) -> String {
        switch reason {
        case .requiresNewerMacOS: return strings.reasonRequiresNewerMacOS
        case .deviceNotEligible: return strings.reasonDeviceNotEligible
        case .appleIntelligenceNotEnabled: return strings.reasonAppleIntelligenceNotEnabled
        case .modelNotReady: return strings.reasonModelNotReady
        case .noProviderConfigured: return strings.reasonNoProviderConfigured
        case .endpointNotAllowed: return strings.reasonEndpointNotAllowed
        }
    }

    private func describe(_ error: AIGenerationError) -> String {
        switch error {
        case .notAvailable(let reason): return describe(reason)
        case .invalidKey: return strings.errorInvalidKey
        case .offline: return strings.errorOffline
        case .timeout: return strings.errorTimeout
        case .rateLimited: return strings.errorRateLimited
        case .httpError(let status): return String(format: strings.errorHTTPFormat, status)
        default: return strings.errorGeneric
        }
    }
}
