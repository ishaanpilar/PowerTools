// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 PowerTools AI contributors

// The Swift 6.0.3 compatibility job builds against Xcode 16.2, whose SDK has
// no FoundationModels at all - not just an unavailable API, the module does
// not exist. `canImport` keeps this entire file compiling to nothing there,
// which is stronger than `@available` alone: that only guards a call site at
// runtime, not the `import` at compile time.
#if canImport(FoundationModels)
import FoundationModels
import Foundation

/// Apple's on-device model. Requires macOS 26 and an eligible Mac with Apple
/// Intelligence turned on; every other Mac reports `.unavailable` and this
/// type makes no network connection under any circumstance.
@available(macOS 26, *)
final class AIOnDeviceTextProvider: AIProvider {
    static let shared = AIOnDeviceTextProvider()

    let id = "apple-on-device"
    // Measured on this Mac (M5, macOS 26.5.2): 4,096-token context window,
    // ~0.6s cold / ~0.3s warm to first token, 70-120 tokens/s while streaming.
    let capabilities = AIProviderCapabilities(
        supportsText: true,
        supportsStreaming: true,
        supportsTypedOutput: true,
        supportsVision: false,
        maxContextTokens: 4096
    )

    private let model = SystemLanguageModel.default

    private init() {}

    func currentAvailability() -> AIProviderAvailability {
        switch model.availability {
        case .available:
            return .ready
        case .unavailable(.deviceNotEligible):
            return .unavailable(.deviceNotEligible)
        case .unavailable(.appleIntelligenceNotEnabled):
            return .unavailable(.appleIntelligenceNotEnabled)
        case .unavailable(.modelNotReady):
            return .unavailable(.modelNotReady)
        case .unavailable:
            // A future SDK reason this app does not know about yet; treat it
            // the same as "not ready" rather than crashing on @unknown default.
            return .unavailable(.modelNotReady)
        }
    }

    /// Call when a surface that may use this provider appears, so the first
    /// real request does not pay the cold-start cost.
    func prewarm() {
        guard case .ready = currentAvailability() else { return }
        session().prewarm()
    }

    func streamText(instructions: String, prompt: String, maxOutputTokens: Int?) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            guard case .ready = currentAvailability() else {
                continuation.finish(throwing: AIGenerationError.notAvailable(unavailableReason()))
                return
            }
            let task = Task {
                do {
                    let options = GenerationOptions(maximumResponseTokens: maxOutputTokens)
                    let stream = session(instructions: instructions).streamResponse(to: prompt, options: options)
                    for try await snapshot in stream {
                        try Task.checkCancellation()
                        continuation.yield(snapshot.content)
                    }
                    continuation.finish()
                } catch is CancellationError {
                    continuation.finish(throwing: AIGenerationError.cancelled)
                } catch let error as LanguageModelSession.GenerationError {
                    continuation.finish(throwing: Self.map(error))
                } catch {
                    continuation.finish(throwing: AIGenerationError.other(String(describing: error)))
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    private func session(instructions: String = "") -> LanguageModelSession {
        LanguageModelSession(instructions: instructions)
    }

    private func unavailableReason() -> AIProviderUnavailableReason {
        guard case .unavailable(let reason) = currentAvailability() else { return .modelNotReady }
        return reason
    }

    static func map(_ error: LanguageModelSession.GenerationError) -> AIGenerationError {
        switch error {
        case .exceededContextWindowSize: return .contextTooLong
        case .assetsUnavailable: return .modelAssetsUnavailable
        case .guardrailViolation: return .refused
        case .refusal: return .refused
        case .unsupportedGuide: return .unsupportedRequest
        case .unsupportedLanguageOrLocale: return .unsupportedLanguage
        case .decodingFailure: return .malformedOutput
        case .rateLimited: return .rateLimited
        case .concurrentRequests: return .tooManyConcurrentRequests
        @unknown default: return .other("unrecognised generation error")
        }
    }
}
#endif
