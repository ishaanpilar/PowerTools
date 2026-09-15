// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 PowerTools AI contributors

import Foundation

enum AITextActionsProviderTests {
    static func run(_ suite: TestSuite) {
        catalogChecks(suite)
        factoryChecks(suite)
        testConnectionChecks(suite)
    }

    private static func catalogChecks(_ suite: TestSuite) {
        suite.expect(
            Set(AITextActionsProviderCatalog.all.map(\.kind)) == Set(AITextActionsProviderKind.allCases)
                && AITextActionsProviderCatalog.all.count == AITextActionsProviderKind.allCases.count,
            "the catalog has exactly one option per provider kind"
        )
        for kind in AITextActionsProviderKind.allCases {
            suite.expect(AITextActionsProviderCatalog.option(for: kind).kind == kind,
                         "option(for: .\(kind)) returns the option for that kind, not some other one")
        }

        let providerIDs = AITextActionsProviderCatalog.all.map(\.providerID)
        suite.expect(Set(providerIDs).count == providerIDs.count,
                     "every provider option has a distinct Keychain/AIProvider id")

        for option in AITextActionsProviderCatalog.all {
            suite.expect(option.privacyURL.scheme == "https",
                         "\(option.kind)'s privacy policy link is HTTPS, not sent in the clear")
        }

        suite.expect(!AITextActionsProviderCatalog.onDevice.requiresKey
                        && AITextActionsProviderCatalog.onDevice.defaultEndpoint == nil
                        && !AITextActionsProviderCatalog.onDevice.endpointIsEditable,
                     "the on-device option has no key, no endpoint, and nothing to edit")
        suite.expect(!AITextActionsProviderCatalog.localServer.requiresKey,
                     "a local server needs no key, matching PRIVACY.md's loopback-only promise")
        for kind: AITextActionsProviderKind in [.deepseek, .openai, .anthropic] {
            let option = AITextActionsProviderCatalog.option(for: kind)
            suite.expect(option.requiresKey && !option.endpointIsEditable && option.modelIsEditable
                            && option.defaultEndpoint != nil && option.defaultModel != nil,
                         "\(kind) is a fixed-endpoint cloud preset: key required, endpoint locked, model overridable")
        }
        for kind: AITextActionsProviderKind in [.custom, .localServer] {
            let option = AITextActionsProviderCatalog.option(for: kind)
            suite.expect(option.endpointIsEditable && option.modelIsEditable && option.defaultModel == nil,
                         "\(kind) has no fixed endpoint or model, so both must be editable")
        }
    }

    private static func factoryChecks(_ suite: TestSuite) {
        let emptyStore = AIProviderKeyStore(
            read: { _ in (errSecItemNotFound, nil) },
            add: { _, _ in errSecSuccess },
            update: { _, _ in errSecItemNotFound },
            delete: { _ in errSecItemNotFound }
        )

        suite.expect(
            AITextActionsProviderFactory.makeProvider(
                for: .init(kind: .custom, model: "", endpoint: ""), keyStore: emptyStore
            ) == nil,
            "custom with nothing typed in builds no provider yet, rather than one that will only fail later"
        )
        suite.expect(
            AITextActionsProviderFactory.makeProvider(
                for: .init(kind: .custom, model: "a-model", endpoint: "not a url"), keyStore: emptyStore
            ) == nil,
            "custom with an unparsable endpoint builds no provider"
        )
        suite.expect(
            AITextActionsProviderFactory.makeProvider(
                for: .init(kind: .localServer, model: "", endpoint: "http://localhost:11434/v1"), keyStore: emptyStore
            ) == nil,
            "local server with no model typed in builds no provider yet"
        )

        if let custom = AITextActionsProviderFactory.makeProvider(
            for: .init(kind: .custom, model: "gpt-4", endpoint: "https://example.com/v1"), keyStore: emptyStore
        ) {
            suite.expect(custom.id == "custom", "a configured custom provider uses the catalog's fixed provider id")
            suite.expect(custom.currentAvailability() == .unavailable(.noProviderConfigured),
                         "a configured custom provider with no stored key reports noProviderConfigured, not ready")
        } else {
            suite.expect(false, "a fully configured custom provider should build")
        }

        if let local = AITextActionsProviderFactory.makeProvider(
            for: .init(kind: .localServer, model: "llama3", endpoint: "http://localhost:11434/v1"), keyStore: emptyStore
        ) {
            suite.expect(local.currentAvailability() == .ready,
                         "a local server needs no key, so a valid loopback endpoint alone is ready")
        } else {
            suite.expect(false, "a fully configured local server provider should build")
        }

        for kind: AITextActionsProviderKind in [.deepseek, .openai, .anthropic] {
            guard let provider = AITextActionsProviderFactory.makeProvider(
                for: .init(kind: kind, model: "", endpoint: ""), keyStore: emptyStore
            ) else {
                suite.expect(false, "\(kind) with its fixed endpoint and default model should build without any settings filled in")
                continue
            }
            suite.expect(provider.id == AITextActionsProviderCatalog.option(for: kind).providerID,
                         "\(kind)'s built provider id matches its catalog entry")
            suite.expect(provider.currentAvailability() == .unavailable(.noProviderConfigured),
                         "\(kind) with no stored key reports noProviderConfigured")
        }

        #if canImport(FoundationModels)
        if #available(macOS 26, *) {
            let onDevice = AITextActionsProviderFactory.makeProvider(for: .init(kind: .onDevice))
            suite.expect(onDevice != nil, "the on-device kind builds a provider when FoundationModels is available")
        }
        #endif
    }

    private static func testConnectionChecks(_ suite: TestSuite) {
        let ready = MockConnectionProvider(availability: .ready, chunks: ["O", "OK"], failure: nil)
        let readyExpectation = DispatchSemaphore(value: 0)
        var readyResult: AITextActionsProviderFactory.ConnectionTestResult?
        Task {
            readyResult = await AITextActionsProviderFactory.testConnection(ready)
            readyExpectation.signal()
        }
        _ = readyExpectation.wait(timeout: .now() + 5)
        suite.expect(readyResult == .success, "a provider that streams text back reports a successful test")

        let unavailable = MockConnectionProvider(availability: .unavailable(.noProviderConfigured), chunks: [], failure: nil)
        let unavailableExpectation = DispatchSemaphore(value: 0)
        var unavailableResult: AITextActionsProviderFactory.ConnectionTestResult?
        Task {
            unavailableResult = await AITextActionsProviderFactory.testConnection(unavailable)
            unavailableExpectation.signal()
        }
        _ = unavailableExpectation.wait(timeout: .now() + 5)
        suite.expect(unavailableResult == .failure(.notAvailable(.noProviderConfigured)),
                     "an unavailable provider is never even asked to stream; its reason surfaces directly")

        let failing = MockConnectionProvider(availability: .ready, chunks: [], failure: .invalidKey)
        let failingExpectation = DispatchSemaphore(value: 0)
        var failingResult: AITextActionsProviderFactory.ConnectionTestResult?
        Task {
            failingResult = await AITextActionsProviderFactory.testConnection(failing)
            failingExpectation.signal()
        }
        _ = failingExpectation.wait(timeout: .now() + 5)
        suite.expect(failingResult == .failure(.invalidKey), "a provider that throws surfaces its own error, unchanged")

        let empty = MockConnectionProvider(availability: .ready, chunks: ["", ""], failure: nil)
        let emptyExpectation = DispatchSemaphore(value: 0)
        var emptyResult: AITextActionsProviderFactory.ConnectionTestResult?
        Task {
            emptyResult = await AITextActionsProviderFactory.testConnection(empty)
            emptyExpectation.signal()
        }
        _ = emptyExpectation.wait(timeout: .now() + 5)
        suite.expect(emptyResult == .failure(.malformedOutput),
                     "a stream that finishes with only empty chunks is treated as a failed test, not a silent success")
    }
}

private struct MockConnectionProvider: AIProvider {
    let id = "mock-connection"
    let capabilities = AIProviderCapabilities(supportsText: true, supportsStreaming: true,
                                              supportsTypedOutput: false, supportsVision: false,
                                              maxContextTokens: nil)
    let availability: AIProviderAvailability
    let chunks: [String]
    let failure: AIGenerationError?

    func currentAvailability() -> AIProviderAvailability { availability }

    func streamText(instructions: String, prompt: String, maxOutputTokens: Int?) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            if let failure {
                continuation.finish(throwing: failure)
                return
            }
            for chunk in chunks { continuation.yield(chunk) }
            continuation.finish()
        }
    }
}
