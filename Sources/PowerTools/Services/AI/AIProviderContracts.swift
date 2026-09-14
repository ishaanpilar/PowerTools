// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 PowerTools AI contributors

import Foundation

/// What a provider can do, so a request only ever reaches a provider able to
/// handle it. Static per provider; a request that needs more than a provider
/// offers goes to a different provider instead of failing partway through.
struct AIProviderCapabilities: Equatable {
    let supportsText: Bool
    let supportsStreaming: Bool
    let supportsTypedOutput: Bool
    let supportsVision: Bool
    /// nil means unknown or effectively unbounded (most cloud providers); a
    /// known on-device limit is exact, since exceeding it is a specific error.
    let maxContextTokens: Int?
}

/// Why a provider cannot serve a request right now. The app decides what to
/// tell the person and which alternative, if any, to offer; this only names
/// the reason.
enum AIProviderUnavailableReason: Hashable {
    case requiresNewerMacOS
    case deviceNotEligible
    case appleIntelligenceNotEnabled
    case modelNotReady
    case noProviderConfigured
    /// The configured endpoint is neither HTTPS nor loopback, so no request
    /// is ever sent to it - checked at availability time, not request time,
    /// so a bad address never quietly waits for the person to trigger it.
    case endpointNotAllowed
}

enum AIProviderAvailability: Hashable {
    case ready
    case unavailable(AIProviderUnavailableReason)
}

/// A provider-independent account of what went wrong generating a response.
/// Concrete providers translate their own errors into this; nothing above
/// the provider layer ever switches on a provider-specific error type.
enum AIGenerationError: Error, Equatable {
    case notAvailable(AIProviderUnavailableReason)
    case contextTooLong
    case modelAssetsUnavailable
    case refused
    case unsupportedRequest
    case unsupportedLanguage
    case malformedOutput
    case rateLimited
    case tooManyConcurrentRequests
    case cancelled
    case invalidKey
    case offline
    case timeout
    case httpError(status: Int)
    case other(String)
}

/// One way to turn text into text. The on-device provider and the HTTP
/// providers (OpenAI-compatible, Anthropic) are the first three; nothing
/// above this protocol may import a provider's own SDK or know its request
/// shape.
protocol AIProvider: Sendable {
    /// Stable, human-readable identity for settings and logs; never used as a
    /// UserDefaults key.
    var id: String { get }
    var capabilities: AIProviderCapabilities { get }

    /// Checked before every request; a provider's availability can change
    /// while the app runs (Apple Intelligence switched off, a key removed).
    func currentAvailability() -> AIProviderAvailability

    /// Yields the cumulative response text as it grows, not a delta. Ends
    /// the stream by throwing `AIGenerationError`, or finishes normally when
    /// generation completes.
    ///
    /// Cancelling the consuming `Task` stops the request, promptly and with
    /// no hang, but - verified against the on-device provider - the stream
    /// then finishes normally rather than throwing `.cancelled`, keeping
    /// whatever partial text had already been yielded. A caller offering a
    /// Cancel button should treat the stream's last-yielded value as the
    /// final result, not wait for a thrown error that may not come.
    func streamText(instructions: String, prompt: String, maxOutputTokens: Int?) -> AsyncThrowingStream<String, Error>
}
