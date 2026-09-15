// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 PowerTools AI contributors

import Foundation

/// What the person has configured for each editable field, independent of
/// where it's stored (UserDefaults via `@AppStorage` in the settings view,
/// or a literal value in a test). `AITextActionsProviderFactory` turns this,
/// plus the selected kind, into a real `AIProvider`.
struct AITextActionsProviderConfiguration {
    var kind: AITextActionsProviderKind
    var model: String = ""
    var endpoint: String = ""
}

enum AITextActionsProviderFactory {
    static let capabilities = AIProviderCapabilities(
        supportsText: true, supportsStreaming: true, supportsTypedOutput: false,
        supportsVision: false, maxContextTokens: nil
    )

    /// Builds the `AIProvider` for the current configuration, or nil when
    /// nothing can be built yet: on-device unavailable at compile time (the
    /// Swift 6.0.3 compatibility job's SDK has no `FoundationModels`), or
    /// custom/local with no endpoint or model typed in yet. Availability at
    /// runtime - missing key, unreachable endpoint - is
    /// `AIProvider.currentAvailability()`'s job, not this function's.
    static func makeProvider(
        for configuration: AITextActionsProviderConfiguration,
        keyStore: AIProviderKeyStore = AIProviderCredentials.liveStore,
        session: URLSession = .shared
    ) -> AIProvider? {
        let option = AITextActionsProviderCatalog.option(for: configuration.kind)
        let model = configuration.model.trimmingCharacters(in: .whitespacesAndNewlines)
        let endpoint = configuration.endpoint.trimmingCharacters(in: .whitespacesAndNewlines)
        let resolvedModel = model.isEmpty ? (option.defaultModel ?? "") : model

        switch configuration.kind {
        case .onDevice:
            #if canImport(FoundationModels)
            if #available(macOS 26, *) {
                return AIOnDeviceTextProvider.shared
            }
            #endif
            return nil

        case .deepseek, .openai:
            guard let endpointURL = option.defaultEndpoint else { return nil }
            return AIOpenAICompatibleProvider(
                id: option.providerID, baseURL: endpointURL, model: resolvedModel,
                keyProviderID: option.providerID, capabilities: capabilities,
                session: session, keyStore: keyStore
            )

        case .anthropic:
            guard let endpointURL = option.defaultEndpoint else { return nil }
            return AIAnthropicProvider(
                id: option.providerID, baseURL: endpointURL, model: resolvedModel,
                keyProviderID: option.providerID, capabilities: capabilities,
                session: session, keyStore: keyStore
            )

        case .custom:
            guard !model.isEmpty, let endpointURL = structuredURL(endpoint) else { return nil }
            return AIOpenAICompatibleProvider(
                id: option.providerID, baseURL: endpointURL, model: model,
                keyProviderID: option.providerID, capabilities: capabilities,
                session: session, keyStore: keyStore
            )

        case .localServer:
            guard !model.isEmpty, let endpointURL = structuredURL(endpoint) else { return nil }
            return AIOpenAICompatibleProvider(
                id: option.providerID, baseURL: endpointURL, model: model,
                keyProviderID: option.providerID, requiresKey: false, capabilities: capabilities,
                session: session, keyStore: keyStore
            )
        }
    }

    /// `URL(string:)` alone is too lenient to catch typos: a plain string
    /// like "not a url" parses successfully as a relative path with no
    /// scheme or host. Requiring both means a structurally incomplete
    /// address builds no provider at all, while a structurally valid one
    /// with a disallowed scheme (e.g. plain http to a real host) still
    /// builds - `currentAvailability()` reports that case as
    /// `.endpointNotAllowed` so the person sees why, instead of nothing.
    private static func structuredURL(_ string: String) -> URL? {
        guard let url = URL(string: string), url.scheme != nil, url.host != nil else { return nil }
        return url
    }

    enum ConnectionTestResult: Equatable {
        case success
        case failure(AIGenerationError)
    }

    /// Sends one minimal real request and reports whether it succeeded.
    /// Only runs when the person explicitly taps Test connection - matching
    /// PRIVACY.md's "nothing is sent until you choose to" for every other AI
    /// surface in the app.
    static func testConnection(_ provider: AIProvider) async -> ConnectionTestResult {
        if case .unavailable(let reason) = provider.currentAvailability() {
            return .failure(.notAvailable(reason))
        }
        do {
            var receivedText = false
            for try await chunk in provider.streamText(
                instructions: "Reply with the single word OK and nothing else.",
                prompt: "Say OK.",
                maxOutputTokens: 8
            ) {
                receivedText = receivedText || !chunk.isEmpty
            }
            return receivedText ? .success : .failure(.malformedOutput)
        } catch let error as AIGenerationError {
            return .failure(error)
        } catch {
            return .failure(.other(String(describing: error)))
        }
    }
}
