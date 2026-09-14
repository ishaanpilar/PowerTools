// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 PowerTools AI contributors

import Foundation

/// The Chat Completions streaming shape shared by OpenAI, DeepSeek, and
/// loopback servers that speak the same protocol (Ollama's OpenAI-compatible
/// endpoint, LM Studio). One adapter covers all of them; only the base URL,
/// model name, and provider id (for the Keychain account and settings UI)
/// differ between instances.
final class AIOpenAICompatibleProvider: AIProvider {
    let id: String
    let capabilities: AIProviderCapabilities
    private let baseURL: URL
    private let model: String
    private let keyProviderID: String
    private let session: URLSession
    private let keyStore: AIProviderKeyStore

    /// `baseURL` should end just before `/chat/completions`, e.g.
    /// `https://api.deepseek.com/v1` or `http://localhost:11434/v1`.
    /// `keyProviderID` is the Keychain account this instance's key is stored
    /// under; loopback servers that need no key can pass `requiresKey: false`.
    init(
        id: String,
        baseURL: URL,
        model: String,
        keyProviderID: String,
        requiresKey: Bool = true,
        capabilities: AIProviderCapabilities,
        session: URLSession = .shared,
        keyStore: AIProviderKeyStore = AIProviderCredentials.liveStore
    ) {
        self.id = id
        self.baseURL = baseURL
        self.model = model
        self.keyProviderID = keyProviderID
        self.requiresKey = requiresKey
        self.capabilities = capabilities
        self.session = session
        self.keyStore = keyStore
    }

    private let requiresKey: Bool

    func currentAvailability() -> AIProviderAvailability {
        guard AIHTTPProviderSupport.isEndpointAllowed(baseURL) else {
            return .unavailable(.endpointNotAllowed)
        }
        if requiresKey, AIProviderCredentials.key(for: keyProviderID, using: keyStore) == nil {
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
        let messages: [Message]
        let stream: Bool
        let max_tokens: Int?

        struct Message: Encodable {
            let role: String
            let content: String
        }
    }

    private struct StreamChunk: Decodable {
        let choices: [Choice]?
        let error: APIError?

        struct Choice: Decodable {
            let delta: Delta?
        }
        struct Delta: Decodable {
            let content: String?
        }
        struct APIError: Decodable {
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

        var apiKey = ""
        if requiresKey {
            guard let key = AIProviderCredentials.key(for: keyProviderID, using: keyStore) else {
                throw AIGenerationError.invalidKey
            }
            apiKey = key
        }

        let url = baseURL.appendingPathComponent("chat/completions")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if requiresKey {
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        }
        let body = RequestBody(
            model: model,
            messages: [
                .init(role: "system", content: instructions),
                .init(role: "user", content: prompt),
            ],
            stream: true,
            max_tokens: maxOutputTokens
        )
        request.httpBody = try JSONEncoder().encode(body)

        let (byteStream, response) = try await session.bytes(for: request)
        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            throw AIHTTPProviderSupport.mapHTTPFailure(status: http.statusCode)
        }

        var accumulated = ""
        for try await event in AIHTTPProviderSupport.events(from: byteStream) {
            try Task.checkCancellation()
            if event == "[DONE]" { continue }
            guard let data = event.data(using: .utf8),
                  let chunk = try? JSONDecoder().decode(StreamChunk.self, from: data)
            else { continue }
            if let apiError = chunk.error {
                throw AIGenerationError.other(apiError.message)
            }
            if let delta = chunk.choices?.first?.delta?.content, !delta.isEmpty {
                accumulated += delta
                onPartial(accumulated)
            }
        }
        return accumulated
    }
}
