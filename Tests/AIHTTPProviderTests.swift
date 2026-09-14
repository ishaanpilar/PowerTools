// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 PowerTools AI contributors

import Foundation

enum AIHTTPProviderTests {
    static func run(_ suite: TestSuite) {
        endpointPolicyChecks(suite)
        sseParsingChecks(suite)
        keychainChecks(suite)
        openAICompatibleChecks(suite)
        anthropicChecks(suite)
    }

    private static func endpointPolicyChecks(_ suite: TestSuite) {
        suite.expect(
            AIHTTPProviderSupport.isEndpointAllowed(URL(string: "https://api.deepseek.com/v1")!)
                && AIHTTPProviderSupport.isEndpointAllowed(URL(string: "https://api.anthropic.com")!),
            "an https endpoint, anywhere, is allowed"
        )
        suite.expect(
            AIHTTPProviderSupport.isEndpointAllowed(URL(string: "http://localhost:11434/v1")!)
                && AIHTTPProviderSupport.isEndpointAllowed(URL(string: "http://127.0.0.1:1234/v1")!),
            "plain http to loopback is allowed, for a local server like Ollama or LM Studio"
        )
        suite.expect(
            !AIHTTPProviderSupport.isEndpointAllowed(URL(string: "http://api.deepseek.com/v1")!)
                && !AIHTTPProviderSupport.isEndpointAllowed(URL(string: "http://example.com")!),
            "plain http to a non-loopback host is refused, so a key is never sent in the clear"
        )
        suite.expect(
            !AIHTTPProviderSupport.isEndpointAllowed(URL(string: "ftp://localhost/v1")!),
            "a non-http(s) scheme is refused even against loopback"
        )
    }

    private static func sseParsingChecks(_ suite: TestSuite) {
        let single = AIHTTPProviderSupport.parseSSE("data: hello\n\n")
        suite.expect(single == ["hello"], "a single SSE event decodes to its data field")

        let multiLine = AIHTTPProviderSupport.parseSSE("data: line one\ndata: line two\n\n")
        suite.expect(multiLine == ["line one\nline two"],
                     "a multi-line data field joins with a newline, per the SSE spec")

        let withOtherFields = AIHTTPProviderSupport.parseSSE("event: content_block_delta\ndata: hi\nid: 1\n\n")
        suite.expect(withOtherFields == ["hi"], "non-data fields (event, id) are discarded")

        let sequence = AIHTTPProviderSupport.parseSSE("data: one\n\ndata: two\n\ndata: [DONE]\n\n")
        suite.expect(sequence == ["one", "two", "[DONE]"],
                     "consecutive events each decode separately, in order")

        var accumulator = AIHTTPProviderSupport.SSEEventAccumulator()
        var events: [String] = []
        for line in ["data: partial", "", "data: rest", ""] {
            if let event = accumulator.feedLine(line) { events.append(event) }
        }
        suite.expect(events == ["partial", "rest"],
                     "the incremental accumulator yields the same events line-by-line as parseSSE does for a whole string")
    }

    private static func keychainChecks(_ suite: TestSuite) {
        var stored: [String: Data] = [:]
        let fake = AIProviderKeyStore(
            read: { account in
                guard let data = stored[account] else { return (errSecItemNotFound, nil) }
                return (errSecSuccess, data)
            },
            add: { account, data in
                guard stored[account] == nil else { return errSecDuplicateItem }
                stored[account] = data
                return errSecSuccess
            },
            update: { account, data in
                guard stored[account] != nil else { return errSecItemNotFound }
                stored[account] = data
                return errSecSuccess
            },
            delete: { account in
                guard stored.removeValue(forKey: account) != nil else { return errSecItemNotFound }
                return errSecSuccess
            }
        )

        suite.expect(AIProviderCredentials.key(for: "deepseek", using: fake) == nil,
                     "no key is stored yet for a provider that hasn't been configured")

        suite.expect(AIProviderCredentials.setKey("sk-test-1", for: "deepseek", using: fake)
                        && AIProviderCredentials.key(for: "deepseek", using: fake) == "sk-test-1",
                     "a key round-trips through the store (add path)")

        suite.expect(AIProviderCredentials.setKey("sk-test-2", for: "deepseek", using: fake)
                        && AIProviderCredentials.key(for: "deepseek", using: fake) == "sk-test-2",
                     "setting a key again updates it in place (update path), not a duplicate")

        suite.expect(AIProviderCredentials.key(for: "anthropic", using: fake) == nil,
                     "a key stored under one provider id is not visible under another")

        suite.expect(AIProviderCredentials.removeKey(for: "deepseek", using: fake)
                        && AIProviderCredentials.key(for: "deepseek", using: fake) == nil,
                     "removing a key deletes it, and a second removal is still reported as success")
        suite.expect(AIProviderCredentials.removeKey(for: "deepseek", using: fake),
                     "removing an already-absent key is not an error, matching CommandBarQueryHabits' own store")

        let defaultsBefore = UserDefaults.standard.dictionaryRepresentation()
        _ = AIProviderCredentials.setKey("sk-should-not-leak", for: "deepseek", using: fake)
        let defaultsAfter = UserDefaults.standard.dictionaryRepresentation()
        suite.expect(defaultsBefore.count == defaultsAfter.count
                        && !defaultsAfter.values.contains(where: { ($0 as? String) == "sk-should-not-leak" }),
                     "storing a provider key never touches UserDefaults")
        _ = AIProviderCredentials.removeKey(for: "deepseek", using: fake)

        let source = (try? String(contentsOfFile: "Sources/PowerTools/Services/AI/AIProviderKeyStore.swift", encoding: .utf8)) ?? ""
        let codeLines = source.split(separator: "\n", omittingEmptySubsequences: false)
            .filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//") }
            .joined(separator: "\n")
        suite.expect(!source.isEmpty && !codeLines.contains("UserDefaults."),
                     "the key store's own code never calls UserDefaults, so a future edit can't reintroduce a leak (its doc comment names UserDefaults only to disclaim it)")
    }

    private static func openAICompatibleChecks(_ suite: TestSuite) {
        let unconfigured = AIOpenAICompatibleProvider(
            id: "deepseek", baseURL: URL(string: "https://api.deepseek.com/v1")!, model: "deepseek-chat",
            keyProviderID: "test-deepseek-unconfigured",
            capabilities: textOnlyCapabilities, session: .shared, keyStore: emptyStore
        )
        suite.expect(unconfigured.currentAvailability() == .unavailable(.noProviderConfigured),
                     "an OpenAI-compatible provider with no stored key reports noProviderConfigured")

        let disallowedEndpoint = AIOpenAICompatibleProvider(
            id: "bad-endpoint", baseURL: URL(string: "http://api.example.com/v1")!, model: "x",
            keyProviderID: "test-bad-endpoint", capabilities: textOnlyCapabilities,
            session: .shared, keyStore: emptyStore
        )
        suite.expect(disallowedEndpoint.currentAvailability() == .unavailable(.endpointNotAllowed),
                     "plain http to a non-loopback endpoint is refused before any key is even checked")

        let loopback = AIOpenAICompatibleProvider(
            id: "ollama", baseURL: URL(string: "http://localhost:11434/v1")!, model: "llama3",
            keyProviderID: "test-loopback-no-key-needed", requiresKey: false,
            capabilities: textOnlyCapabilities, session: .shared, keyStore: emptyStore
        )
        suite.expect(loopback.currentAvailability() == .ready,
                     "a loopback server configured to need no key is ready without one")

        let sseBody = [
            "data: {\"choices\":[{\"delta\":{\"content\":\"Hel\"}}]}",
            "",
            "data: {\"choices\":[{\"delta\":{\"content\":\"lo\"}}]}",
            "",
            "data: {\"choices\":[{\"delta\":{\"content\":\" caf\\u00e9\"}}]}",
            "",
            "data: [DONE]",
            "",
            "",
        ].joined(separator: "\n")
        let (session, keyStore) = mockSession(status: 200, body: sseBody, splitMidUTF8: true)
        let live = AIOpenAICompatibleProvider(
            id: "deepseek", baseURL: URL(string: "https://api.deepseek.com/v1")!, model: "deepseek-chat",
            keyProviderID: "test-deepseek-live", capabilities: textOnlyCapabilities,
            session: session, keyStore: keyStore
        )
        _ = AIProviderCredentials.setKey("sk-fake-for-test", for: "test-deepseek-live", using: keyStore)
        let (collected, error) = collect(live.streamText(instructions: "", prompt: "hi", maxOutputTokens: nil))
        suite.expect(error == nil, "a well-formed SSE stream, split mid-character across network reads, yields no error")
        suite.expect(collected.last == "Hello caf\u{00e9}",
                     "accumulated content survives a multi-byte UTF-8 character split across two reads intact")
        suite.expect(collected == ["Hel", "Hello", "Hello caf\u{00e9}"],
                     "each SSE delta yields the cumulative text so far, in order")

        let (errorSession, errorKeyStore) = mockSession(status: 401, body: "{\"error\":\"unauthorized\"}")
        let unauthorized = AIOpenAICompatibleProvider(
            id: "deepseek", baseURL: URL(string: "https://api.deepseek.com/v1")!, model: "deepseek-chat",
            keyProviderID: "test-deepseek-401", capabilities: textOnlyCapabilities,
            session: errorSession, keyStore: errorKeyStore
        )
        _ = AIProviderCredentials.setKey("sk-bad", for: "test-deepseek-401", using: errorKeyStore)
        let (_, unauthorizedError) = collect(unauthorized.streamText(instructions: "", prompt: "hi", maxOutputTokens: nil))
        suite.expect(unauthorizedError as? AIGenerationError == .invalidKey,
                     "a 401 response maps to invalidKey, not a generic HTTP error")
    }

    private static func anthropicChecks(_ suite: TestSuite) {
        let unconfigured = AIAnthropicProvider(
            id: "anthropic", baseURL: URL(string: "https://api.anthropic.com")!, model: "claude-haiku",
            keyProviderID: "test-anthropic-unconfigured", capabilities: textOnlyCapabilities,
            session: .shared, keyStore: emptyStore
        )
        suite.expect(unconfigured.currentAvailability() == .unavailable(.noProviderConfigured),
                     "an Anthropic provider with no stored key reports noProviderConfigured")

        let sseBody = [
            "event: content_block_delta",
            "data: {\"type\":\"content_block_delta\",\"delta\":{\"type\":\"text_delta\",\"text\":\"Hi\"}}",
            "",
            "event: content_block_delta",
            "data: {\"type\":\"content_block_delta\",\"delta\":{\"type\":\"text_delta\",\"text\":\" there\"}}",
            "",
            "event: message_stop",
            "data: {\"type\":\"message_stop\"}",
            "",
            "",
        ].joined(separator: "\n")
        let (session, keyStore) = mockSession(status: 200, body: sseBody)
        let live = AIAnthropicProvider(
            id: "anthropic", baseURL: URL(string: "https://api.anthropic.com")!, model: "claude-haiku",
            keyProviderID: "test-anthropic-live", capabilities: textOnlyCapabilities,
            session: session, keyStore: keyStore
        )
        _ = AIProviderCredentials.setKey("sk-ant-fake", for: "test-anthropic-live", using: keyStore)
        let (collected, error) = collect(live.streamText(instructions: "", prompt: "hi", maxOutputTokens: nil))
        suite.expect(error == nil && collected.last == "Hi there",
                     "content_block_delta events accumulate into the final text; message_stop carries no text and is skipped")

        let errorSSE = [
            "event: error",
            "data: {\"type\":\"error\",\"error\":{\"type\":\"overloaded_error\",\"message\":\"Overloaded\"}}",
            "",
            "",
        ].joined(separator: "\n")
        let (errSession, errKeyStore) = mockSession(status: 200, body: errorSSE)
        let erroring = AIAnthropicProvider(
            id: "anthropic", baseURL: URL(string: "https://api.anthropic.com")!, model: "claude-haiku",
            keyProviderID: "test-anthropic-error", capabilities: textOnlyCapabilities,
            session: errSession, keyStore: errKeyStore
        )
        _ = AIProviderCredentials.setKey("sk-ant-fake", for: "test-anthropic-error", using: errKeyStore)
        let (_, errorResult) = collect(erroring.streamText(instructions: "", prompt: "hi", maxOutputTokens: nil))
        if case .other(let message)? = errorResult as? AIGenerationError {
            suite.expect(message == "Overloaded", "an in-stream `error` event surfaces the API's own message")
        } else {
            suite.expect(false, "an in-stream `error` event surfaces the API's own message")
        }
    }

    // MARK: - Test helpers

    private static let textOnlyCapabilities = AIProviderCapabilities(
        supportsText: true, supportsStreaming: true, supportsTypedOutput: false,
        supportsVision: false, maxContextTokens: nil
    )

    private static var emptyStore: AIProviderKeyStore {
        AIProviderKeyStore(
            read: { _ in (errSecItemNotFound, nil) },
            add: { _, _ in errSecSuccess },
            update: { _, _ in errSecItemNotFound },
            delete: { _ in errSecItemNotFound }
        )
    }

    /// A fresh in-memory Keychain stand-in and a `URLSession` that always
    /// returns `body` for every request, via `MockURLProtocol`. When
    /// `splitMidUTF8` is set, the body is delivered in two network reads cut
    /// in the middle of a multi-byte UTF-8 character, to prove the
    /// line-buffered decoder never corrupts it (unlike decoding byte-by-byte).
    private static func mockSession(status: Int, body: String, splitMidUTF8: Bool = false) -> (URLSession, AIProviderKeyStore) {
        var stored: [String: Data] = [:]
        let keyStore = AIProviderKeyStore(
            read: { account in
                guard let data = stored[account] else { return (errSecItemNotFound, nil) }
                return (errSecSuccess, data)
            },
            add: { account, data in stored[account] = data; return errSecSuccess },
            update: { account, data in
                guard stored[account] != nil else { return errSecItemNotFound }
                stored[account] = data
                return errSecSuccess
            },
            delete: { account in stored.removeValue(forKey: account) != nil ? errSecSuccess : errSecItemNotFound }
        )

        let bodyData = Data(body.utf8)
        let chunks: [Data]
        if splitMidUTF8, let cafRange = body.range(of: "caf"), let byteIndex = cafRange.upperBound.samePosition(in: body.utf8) {
            // 'é' encodes as two UTF-8 bytes (0xC3 0xA9); split between them,
            // right after "caf" plus the first byte of 'é', so the second
            // read starts mid-character.
            let splitPoint = body.utf8.distance(from: body.utf8.startIndex, to: byteIndex) + 1
            chunks = [bodyData.prefix(splitPoint), bodyData.suffix(from: splitPoint)]
        } else {
            chunks = [bodyData]
        }
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockURLProtocol.self]
        let session = URLSession(configuration: configuration)
        MockURLProtocol.nextResponse = (status, chunks)
        return (session, keyStore)
    }

    private static func collect(_ stream: AsyncThrowingStream<String, Error>) -> ([String], Error?) {
        var collected: [String] = []
        var streamError: Error?
        let expectation = DispatchSemaphore(value: 0)
        Task {
            do {
                for try await chunk in stream { collected.append(chunk) }
            } catch {
                streamError = error
            }
            expectation.signal()
        }
        _ = expectation.wait(timeout: .now() + 5)
        return (collected, streamError)
    }
}

/// Intercepts every request on a session configured with it and replays
/// `nextResponse`, in as many `didLoad` chunks as it was given - so a test
/// can force a multi-byte UTF-8 character to land split across two network
/// reads, the exact case that would break a byte-by-byte decoder.
private final class MockURLProtocol: URLProtocol {
    nonisolated(unsafe) static var nextResponse: (status: Int, chunks: [Data]) = (200, [])

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        let (status, chunks) = Self.nextResponse
        let response = HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: "HTTP/1.1", headerFields: nil)!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        for chunk in chunks {
            client?.urlProtocol(self, didLoad: chunk)
        }
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}
