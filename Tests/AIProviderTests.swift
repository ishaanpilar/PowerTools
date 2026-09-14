// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 PowerTools AI contributors

import Foundation

enum AIProviderTests {
    static func run(_ suite: TestSuite) {
        suite.expect(
            AIProviderCapabilities(supportsText: true, supportsStreaming: true,
                                   supportsTypedOutput: false, supportsVision: false,
                                   maxContextTokens: 4096)
                == AIProviderCapabilities(supportsText: true, supportsStreaming: true,
                                          supportsTypedOutput: false, supportsVision: false,
                                          maxContextTokens: 4096)
                && AIProviderCapabilities(supportsText: true, supportsStreaming: true,
                                          supportsTypedOutput: false, supportsVision: false,
                                          maxContextTokens: 4096)
                != AIProviderCapabilities(supportsText: true, supportsStreaming: false,
                                          supportsTypedOutput: false, supportsVision: false,
                                          maxContextTokens: 4096),
            "provider capabilities compare by value"
        )

        let reasons: [AIProviderUnavailableReason] = [
            .requiresNewerMacOS, .deviceNotEligible, .appleIntelligenceNotEnabled,
            .modelNotReady, .noProviderConfigured,
        ]
        suite.expect(Set(reasons.map { AIProviderAvailability.unavailable($0) }).count == reasons.count
                        && AIProviderAvailability.ready != .unavailable(.modelNotReady),
                     "provider availability distinguishes ready from each unavailable reason")

        let mock = MockAIProvider(
            id: "mock",
            capabilities: AIProviderCapabilities(supportsText: true, supportsStreaming: true,
                                                 supportsTypedOutput: false, supportsVision: false,
                                                 maxContextTokens: nil),
            availability: .ready,
            chunks: ["Hel", "Hello", "Hello!"]
        )
        var collected: [String] = []
        var streamError: Error?
        let expectation = DispatchSemaphore(value: 0)
        Task {
            do {
                for try await chunk in mock.streamText(instructions: "", prompt: "hi", maxOutputTokens: nil) {
                    collected.append(chunk)
                }
            } catch {
                streamError = error
            }
            expectation.signal()
        }
        _ = expectation.wait(timeout: .now() + 5)
        suite.expect(collected == ["Hel", "Hello", "Hello!"] && streamError == nil,
                     "a mock provider satisfies the AIProvider contract and streams in order")

        let failingMock = MockAIProvider(
            id: "mock-unavailable", capabilities: mock.capabilities,
            availability: .unavailable(.appleIntelligenceNotEnabled), chunks: []
        )
        var failure: AIGenerationError?
        let failureExpectation = DispatchSemaphore(value: 0)
        Task {
            do {
                for try await _ in failingMock.streamText(instructions: "", prompt: "hi", maxOutputTokens: nil) {}
            } catch let error as AIGenerationError {
                failure = error
            } catch {}
            failureExpectation.signal()
        }
        _ = failureExpectation.wait(timeout: .now() + 5)
        suite.expect(failure == .notAvailable(.appleIntelligenceNotEnabled),
                     "an unavailable provider fails the stream instead of yielding nothing silently")

        #if canImport(FoundationModels)
        if #available(macOS 26, *) {
            let onDevice = AIOnDeviceTextProvider.shared
            suite.expect(onDevice.capabilities.maxContextTokens == 4096
                            && onDevice.capabilities.supportsStreaming
                            && !onDevice.capabilities.supportsVision,
                         "the on-device provider reports its measured capabilities")

            let availability = onDevice.currentAvailability()
            let known: [AIProviderAvailability] = [
                .ready, .unavailable(.deviceNotEligible),
                .unavailable(.appleIntelligenceNotEnabled), .unavailable(.modelNotReady),
            ]
            suite.expect(known.contains(availability),
                         "the on-device provider's availability matches a known case without crashing")
        }
        #endif
    }
}

/// A fixed-script provider for testing the `AIProvider` contract without the
/// real model: predetermined chunks, or a fixed failure, with no timing or
/// hardware dependency.
private struct MockAIProvider: AIProvider {
    let id: String
    let capabilities: AIProviderCapabilities
    let availability: AIProviderAvailability
    let chunks: [String]

    func currentAvailability() -> AIProviderAvailability { availability }

    func streamText(instructions: String, prompt: String, maxOutputTokens: Int?) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            guard case .ready = availability else {
                if case .unavailable(let reason) = availability {
                    continuation.finish(throwing: AIGenerationError.notAvailable(reason))
                } else {
                    continuation.finish(throwing: AIGenerationError.other("unreachable"))
                }
                return
            }
            for chunk in chunks { continuation.yield(chunk) }
            continuation.finish()
        }
    }
}
