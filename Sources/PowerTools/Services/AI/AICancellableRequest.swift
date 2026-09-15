// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 PowerTools AI contributors

import Foundation

/// Wraps one in-flight AI stream so a Cancel button can stop it without the
/// caller managing its own `Task` handle - roadmap 2.7's "cancel on every
/// request", consumed by the Cancel button in each feature that sends one
/// (starting with Command Bar text actions).
///
/// Cancelling stops the request promptly, but - verified against the
/// on-device provider in task 02, and true of the HTTP adapters' shared
/// `URLSession.bytes(for:)` plumbing for the same reason - the stream then
/// finishes normally with whatever partial text had already arrived, rather
/// than throwing. `onUpdate` already received that partial text as it
/// streamed, so there is nothing more for a caller to read after cancelling;
/// `onFinish` is not called for a request this same instance has cancelled.
///
/// `onUpdate`/`onFinish` always fire on the main actor: `run`'s internal
/// `Task` explicitly hops there (`Task { @MainActor in ... }`), rather than
/// relying on whichever context happens to call `run` - a plain method
/// merely *executing on the main thread* does not make a `Task` created
/// inside it main-actor-isolated; only an actually-isolated caller (SwiftUI's
/// `.task { }`, or another `@MainActor` context) would propagate that. A
/// first version of this type assumed otherwise and called AppKit layout
/// APIs from a background thread as a result - a real crash
/// (`_AssertAutoLayoutOnAllowedThreadsOnly`), not a theoretical one, caught
/// by actually running the feature live rather than by inspection. The type
/// itself stays a plain class (not `@MainActor`) so a caller - including a
/// unit test - can still create and cancel it from anywhere; only the
/// callbacks are pinned.
final class AICancellableRequest {
    private var task: Task<Void, Never>?

    /// Cancels any request already running on this instance, then starts
    /// the new one. `onUpdate` receives the cumulative text as it grows,
    /// matching `AIProvider.streamText`'s own contract.
    func run(
        _ stream: AsyncThrowingStream<String, Error>,
        onUpdate: @escaping (String) -> Void,
        onFinish: @escaping (Result<Void, Error>) -> Void
    ) {
        cancel()
        let current = Task { @MainActor in
            do {
                for try await chunk in stream {
                    try Task.checkCancellation()
                    onUpdate(chunk)
                }
                try Task.checkCancellation()
                onFinish(.success(()))
            } catch is CancellationError {
                // Cancelled by this instance: the caller already has every
                // update it's going to get, and asked to stop, not to be
                // told the request it cancelled is now finished.
            } catch {
                onFinish(.failure(error))
            }
        }
        task = current
    }

    func cancel() {
        task?.cancel()
        task = nil
    }

    var isRunning: Bool { task != nil }
}
