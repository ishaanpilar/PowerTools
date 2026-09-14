// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 PowerTools AI contributors

import Foundation

/// Shared plumbing for every HTTP-backed `AIProvider` (OpenAI-compatible,
/// Anthropic): the endpoint policy both adapters enforce, SSE parsing for
/// the "data: {...}" framing both APIs use, and URLSession/HTTP error
/// mapping. Kept separate from the adapters themselves so the policy is
/// enforced identically instead of re-implemented per provider.
enum AIHTTPProviderSupport {
    /// A request is only ever sent to HTTPS, or to loopback for a local
    /// server (Ollama, LM Studio). Plain HTTP to a non-loopback host would
    /// send the API key in the clear, so it is refused before a connection
    /// is ever opened - `AIProviderUnavailableReason.endpointNotAllowed`.
    static func isEndpointAllowed(_ url: URL) -> Bool {
        guard let scheme = url.scheme?.lowercased(), let host = url.host?.lowercased() else {
            return false
        }
        if scheme == "https" { return true }
        if scheme == "http" { return isLoopbackHost(host) }
        return false
    }

    static func isLoopbackHost(_ host: String) -> Bool {
        host == "localhost" || host == "127.0.0.1" || host == "::1"
    }

    /// One decoded Server-Sent Event: everything between blank lines, with
    /// only the `data:` field kept (both APIs' `event:` field is informative,
    /// not needed to reconstruct the text - the JSON payload in `data:`
    /// already carries its own `type`). Multi-line `data:` fields join with
    /// `\n`, per the SSE spec. For a whole buffered string, not the wire;
    /// a live stream decodes line-by-line through `SSEEventAccumulator`
    /// instead, so a multi-byte UTF-8 character split across two network
    /// reads is never decoded from a half-received byte.
    static func parseSSE(_ raw: String) -> [String] {
        var accumulator = SSEEventAccumulator()
        var events: [String] = []
        for line in raw.split(separator: "\n", omittingEmptySubsequences: false) {
            if let event = accumulator.feedLine(String(line)) {
                events.append(event)
            }
        }
        if let trailing = accumulator.flush() {
            events.append(trailing)
        }
        return events
    }

    /// Feed complete lines (already split on `\n`, no trailing newline) one
    /// at a time; returns the joined `data:` text whenever a blank line
    /// completes an event, `nil` otherwise. Lines must be decoded from
    /// complete byte runs - see `AIOpenAICompatibleProvider`/`AIAnthropicProvider`'s
    /// byte readers, which buffer raw bytes until a `\n` byte before ever
    /// calling `String(decoding:as:)`, so a multi-byte character split
    /// across two network reads is never decoded from a half-received byte.
    struct SSEEventAccumulator {
        private var dataLines: [String] = []

        mutating func feedLine(_ line: String) -> String? {
            if line.isEmpty {
                return flush()
            }
            if line.hasPrefix("data:") {
                let value = line.dropFirst("data:".count)
                dataLines.append(value.hasPrefix(" ") ? String(value.dropFirst()) : String(value))
            }
            // Any other field (event:, id:, :comment) carries no text we need.
            return nil
        }

        mutating func flush() -> String? {
            guard !dataLines.isEmpty else { return nil }
            let event = dataLines.joined(separator: "\n")
            dataLines.removeAll()
            return event
        }
    }

    /// Maps a failed HTTP response to the provider-independent error. Every
    /// provider covered here (OpenAI-compatible, Anthropic) uses 401/403 for
    /// a bad or missing key and 429 for rate limiting; anything else keeps
    /// its status code rather than collapsing into one generic failure.
    static func mapHTTPFailure(status: Int) -> AIGenerationError {
        switch status {
        case 401, 403:
            return .invalidKey
        case 429:
            return .rateLimited
        default:
            return .httpError(status: status)
        }
    }

    /// Decodes an `URLSession.AsyncBytes` stream into complete SSE events,
    /// one per blank-line-terminated block. Buffers raw bytes until a `\n`
    /// byte (0x0A) before decoding, so a multi-byte UTF-8 character split
    /// across two network reads is decoded whole, never from a half-received
    /// byte - unlike decoding byte-by-byte, which would treat each byte as
    /// its own Latin-1 codepoint and corrupt any non-ASCII text.
    static func events(from byteStream: URLSession.AsyncBytes) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                var lineBuffer: [UInt8] = []
                var accumulator = SSEEventAccumulator()
                do {
                    for try await byte in byteStream {
                        try Task.checkCancellation()
                        if byte == 0x0A {
                            if lineBuffer.last == 0x0D { lineBuffer.removeLast() }
                            let line = String(decoding: lineBuffer, as: UTF8.self)
                            lineBuffer.removeAll(keepingCapacity: true)
                            if let event = accumulator.feedLine(line) {
                                continuation.yield(event)
                            }
                        } else {
                            lineBuffer.append(byte)
                        }
                    }
                    if !lineBuffer.isEmpty {
                        let line = String(decoding: lineBuffer, as: UTF8.self)
                        _ = accumulator.feedLine(line)
                    }
                    if let trailing = accumulator.flush() {
                        continuation.yield(trailing)
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    static func mapTransportError(_ error: Error) -> AIGenerationError {
        if error is CancellationError { return .cancelled }
        guard let urlError = error as? URLError else { return .other(String(describing: error)) }
        switch urlError.code {
        case .timedOut:
            return .timeout
        case .notConnectedToInternet, .networkConnectionLost, .cannotConnectToHost,
             .cannotFindHost, .dnsLookupFailed:
            return .offline
        case .cancelled:
            return .cancelled
        default:
            return .other(urlError.localizedDescription)
        }
    }
}
