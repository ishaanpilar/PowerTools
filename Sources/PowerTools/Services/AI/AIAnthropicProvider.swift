// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 PowerTools AI contributors

import Foundation

/// The Messages API's streaming shape: a distinct request/response body from
/// the Chat Completions family, and a distinct auth header (`x-api-key`, not
/// `Authorization: Bearer`), so it gets its own adapter rather than trying to
/// squeeze it into `AIOpenAICompatibleProvider`.
final class AIAnthropicProvider: AIProvider {
    let id: String
    let capabilities: AIProviderCapabilities
    private let baseURL: URL
    private let model: String
    private let keyProviderID: String
    private let session: URLSession
    private let keyStore: AIProviderKeyStore

    /// `baseURL` should end just before `/v1/messages`, e.g.
    /// `https://api.anthropic.com`.
    init(
        id: String,
        baseURL: URL,
        model: String,
        keyProviderID: String,
        capabilities: AIProviderCapabilities,
        session: URLSession = .shared,
        keyStore: AIProviderKeyStore = AIProviderCredentials.liveStore
    ) {
        self.id = id
        self.baseURL = baseURL
        self.model = model
        self.keyProviderID = keyProviderID
        self.capabilities = capabilities
        self.session = session
        self.keyStore = keyStore
    }

    static let apiVersion = "2023-06-01"
    /// The Messages API requires `max_tokens`; unlike Chat Completions it has
    /// no "unbounded" option, so a caller that passes nil still gets a cap.
    static let defaultMaxTokens = 4096

    func currentAvailability() -> AIProviderAvailability {
        guard AIHTTPProviderSupport.isEndpointAllowed(baseURL) else {
            return .unavailable(.endpointNotAllowed)
        }
        if AIProviderCredentials.key(for: keyProviderID, using: keyStore) == nil {
            return .unavailable(.noProviderConfigured)
        }
        return .ready
    }

    func streamText(instructions: String, prompt: String, maxOutputTokens: Int?) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    // Each delta already yields the cumulative text so far via
                    // `onPartial`; the last such yield equals the returned
                    // value, so it is not re-yielded here.
                    _ = try await self.run(instructions: instructions, prompt: prompt, maxOutputTokens: maxOutputTokens) { partial in
                        continuation.yield(partial)
                    }
                    continuation.finish()
                } catch is CancellationError {
                    continuation.finish()
                } catch let error as AIGenerationError {
                    continuation.finish(throwing: error)
                } catch {
                    continuation.finish(throwing: AIHTTPProviderSupport.mapTransportError(error))
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    private struct RequestBody: Encodable {
        let model: String
        let system: String
        let messages: [Message]
        let max_tokens: Int
        let stream: Bool

        struct Message: Encodable {
            let role: String
            let content: String
        }
    }

    /// Covers the event shapes this adapter needs (`content_block_delta`'s
    /// text and the `error` event); other fields of `message_start`,
    /// `content_block_start`, `message_delta`, `message_stop`, and `ping`
    /// carry nothing the accumulated text needs, so they decode as `nil` and
    /// are skipped rather than modeled field-by-field.
    private struct StreamEvent: Decodable {
        let type: String
        let delta: Delta?
        let error: APIError?

        struct Delta: Decodable {
            let type: String?
            let text: String?
        }
        struct APIError: Decodable {
            let type: String
            let message: String
        }
    }

    private func run(
        instructions: String,
        prompt: String,
        maxOutputTokens: Int?,
        onPartial: @escaping (String) -> Void
    ) async throws -> String {
        if case .unavailable(let reason) = currentAvailability() {
            throw AIGenerationError.notAvailable(reason)
        }
        guard let apiKey = AIProviderCredentials.key(for: keyProviderID, using: keyStore) else {
            throw AIGenerationError.invalidKey
        }

        let url = baseURL.appendingPathComponent("v1/messages")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue(Self.apiVersion, forHTTPHeaderField: "anthropic-version")
        let body = RequestBody(
            model: model,
            system: instructions,
            messages: [.init(role: "user", content: prompt)],
            max_tokens: maxOutputTokens ?? Self.defaultMaxTokens,
            stream: true
        )
        request.httpBody = try JSONEncoder().encode(body)

        let (byteStream, response) = try await session.bytes(for: request)
        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            throw AIHTTPProviderSupport.mapHTTPFailure(status: http.statusCode)
        }

        var accumulated = ""
        for try await event in AIHTTPProviderSupport.events(from: byteStream) {
            try Task.checkCancellation()
            guard let data = event.data(using: .utf8),
                  let decoded = try? JSONDecoder().decode(StreamEvent.self, from: data)
            else { continue }
            if decoded.type == "error", let apiError = decoded.error {
                throw AIGenerationError.other(apiError.message)
            }
            if decoded.type == "content_block_delta", decoded.delta?.type == "text_delta",
               let text = decoded.delta?.text, !text.isEmpty {
                accumulated += text
                onPartial(accumulated)
            }
        }
        return accumulated
    }
}
