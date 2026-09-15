// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 PowerTools AI contributors

import Foundation

enum AIContextManifestTests {
    static func run(_ suite: TestSuite) {
        manifestBuilderChecks(suite)
        previewTrackerChecks(suite)
        cancellableRequestChecks(suite)
    }

    private static func manifestBuilderChecks(_ suite: TestSuite) {
        let strings = AITextActionsFeatureStrings.enUS
        let text = "Hello, world!"

        for kind in AITextActionsProviderKind.allCases {
            let option = AITextActionsProviderCatalog.option(for: kind)
            let manifest = AIContextManifestBuilder.selectedText(text, option: option, strings: strings)

            suite.expect(manifest.contentType == AIContextManifestBuilder.selectedTextContentType,
                         "\(kind)'s manifest uses the shared selected-text content type id")
            suite.expect(manifest.contentTypeLabel == strings.previewContentTypeSelectedText,
                         "\(kind)'s manifest labels its content type from the strings catalog")
            suite.expect(manifest.itemCount == 1, "\(kind)'s manifest counts one selection as one item")
            suite.expect(manifest.approximateSizeBytes == text.utf8.count,
                         "\(kind)'s manifest sizes the request from the actual UTF-8 byte count")
            suite.expect(manifest.boundary == option.boundary,
                         "\(kind)'s manifest boundary matches its catalog entry")
            suite.expect(manifest.providerID == option.providerID, "\(kind)'s manifest names the right provider id")
            suite.expect(manifest.providerDisplayName == AITextActionsProviderCatalog.displayName(for: kind, strings: strings),
                         "\(kind)'s manifest display name matches the catalog helper, not a separate copy of the mapping")
            suite.expect(manifest.privacyURL == option.privacyURL, "\(kind)'s manifest privacy link matches its catalog entry")

            let expectedRetention = option.boundary == .local ? strings.previewRetentionLocal : strings.previewRetentionRemote
            suite.expect(manifest.retentionNote == expectedRetention,
                         "\(kind)'s retention note follows from its boundary, not a per-provider copy")
        }

        suite.expect(AITextActionsProviderCatalog.onDevice.boundary == .local
                        && AITextActionsProviderCatalog.localServer.boundary == .local,
                     "on-device and a local server both stay on the Mac, even though only one needs no key")
        suite.expect(AITextActionsProviderCatalog.deepseek.boundary == .remote
                        && AITextActionsProviderCatalog.openai.boundary == .remote
                        && AITextActionsProviderCatalog.anthropic.boundary == .remote
                        && AITextActionsProviderCatalog.custom.boundary == .remote,
                     "every HTTP provider except the local server leaves the Mac")
    }

    private static func previewTrackerChecks(_ suite: TestSuite) {
        let suiteName = "com.powertools.tests.aiPreSendPreview"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        defer { defaults.removePersistentDomain(forName: suiteName) }

        suite.expect(!AIPreSendPreviewTracker.hasShownPreview(contentType: "selected-text", providerID: "deepseek", defaults: defaults),
                     "a combination that's never been recorded has not been shown")

        AIPreSendPreviewTracker.recordPreviewShown(contentType: "selected-text", providerID: "deepseek", defaults: defaults)
        suite.expect(AIPreSendPreviewTracker.hasShownPreview(contentType: "selected-text", providerID: "deepseek", defaults: defaults),
                     "recording a preview makes hasShownPreview true for that exact combination")

        suite.expect(!AIPreSendPreviewTracker.hasShownPreview(contentType: "selected-text", providerID: "openai", defaults: defaults),
                     "recording deepseek's preview does not mark openai as shown")
        suite.expect(!AIPreSendPreviewTracker.hasShownPreview(contentType: "clipboard-item", providerID: "deepseek", defaults: defaults),
                     "recording selected-text's preview does not mark a different content type as shown, even for the same provider")

        AIPreSendPreviewTracker.reset(contentType: "selected-text", providerID: "deepseek", defaults: defaults)
        suite.expect(!AIPreSendPreviewTracker.hasShownPreview(contentType: "selected-text", providerID: "deepseek", defaults: defaults),
                     "reset reverses a recorded preview")

        let source = (try? String(contentsOfFile: "Sources/PowerTools/Services/AI/AIPreSendPreviewTracker.swift", encoding: .utf8)) ?? ""
        let codeLines = source.split(separator: "\n", omittingEmptySubsequences: false)
            .filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//") }
            .joined(separator: "\n")
        suite.expect(!source.isEmpty && !codeLines.contains("Security") && !codeLines.contains("SecItem"),
                     "the preview tracker never touches the Keychain; it records a courtesy flag, not a secret")
    }

    private static func cancellableRequestChecks(_ suite: TestSuite) {
        runAsync {
            let request = AICancellableRequest()
            let (updates, result) = await runToCompletion(request, scriptedStream(["Hel", "Hello", "Hello!"]))
            suite.expect(updates == ["Hel", "Hello", "Hello!"], "every yielded chunk reaches onUpdate, in order")
            if case .success = result {
                suite.expect(true, "a stream that completes normally finishes with success")
            } else {
                suite.expect(false, "a stream that completes normally finishes with success")
            }
        }

        runAsync {
            let request = AICancellableRequest()
            var updateCount = 0
            var finishCalled = false
            request.run(
                slowScriptedStream(["one", "two", "three", "four"]),
                onUpdate: { _ in updateCount += 1 },
                onFinish: { _ in finishCalled = true }
            )
            // Suspend, never block: each chunk is ~100ms apart, so 150ms lets
            // roughly one through before cancelling mid-stream.
            try? await Task.sleep(nanoseconds: 150_000_000)
            request.cancel()
            try? await Task.sleep(nanoseconds: 300_000_000)
            suite.expect(!finishCalled, "cancelling this instance's own request never calls onFinish")
            suite.expect(updateCount < 4, "cancelling stops the stream before every chunk arrives")
            suite.expect(!request.isRunning, "cancel() clears the running task")
        }

        runAsync {
            let request = AICancellableRequest()
            let (_, result) = await runToCompletion(request, failingStream(.invalidKey))
            if case .failure(let error as AIGenerationError) = result {
                suite.expect(error == .invalidKey, "a thrown provider error passes through onFinish unchanged")
            } else {
                suite.expect(false, "a thrown provider error passes through onFinish unchanged")
            }
        }

        runAsync {
            let request = AICancellableRequest()
            var firstFinished = false
            request.run(scriptedStream(["a"]), onUpdate: { _ in }, onFinish: { _ in firstFinished = true })
            let (_, secondResult) = await runToCompletion(request, scriptedStream(["b"]))
            suite.expect(!firstFinished, "starting a second request cancels the first, which never reaches onFinish")
            if case .success = secondResult {
                suite.expect(true, "the second request runs to completion normally")
            } else {
                suite.expect(false, "the second request runs to completion normally")
            }
        }
    }

    /// Bridges `AICancellableRequest`'s callback API into async/await with a
    /// continuation, not a blocking `DispatchSemaphore.wait()` - unavailable
    /// from an async context in Swift 6 mode, and unsound here regardless:
    /// blocking the thread a callback needs in order to fire would starve
    /// the very callback being waited for.
    private static func runToCompletion(
        _ request: AICancellableRequest,
        _ stream: AsyncThrowingStream<String, Error>
    ) async -> (updates: [String], result: Result<Void, Error>) {
        var updates: [String] = []
        let result = await withCheckedContinuation { (continuation: CheckedContinuation<Result<Void, Error>, Never>) in
            request.run(stream, onUpdate: { updates.append($0) }, onFinish: { continuation.resume(returning: $0) })
        }
        return (updates, result)
    }

    private static func scriptedStream(_ chunks: [String]) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            for chunk in chunks { continuation.yield(chunk) }
            continuation.finish()
        }
    }

    private static func slowScriptedStream(_ chunks: [String]) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                for chunk in chunks {
                    try? await Task.sleep(nanoseconds: 100_000_000)
                    if Task.isCancelled { break }
                    continuation.yield(chunk)
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    private static func failingStream(_ error: AIGenerationError) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            continuation.finish(throwing: error)
        }
    }

    /// Runs `work` and waits for it to finish by pumping the main run loop in
    /// short bursts, not by blocking this (synchronous, non-async) thread on
    /// a semaphore. `AICancellableRequest`'s callbacks are pinned to the main
    /// actor, whose default executor is `DispatchQueue.main` - this test
    /// runner's own `main()` already occupies that exact thread, so a
    /// blocking `DispatchSemaphore.wait()` here would starve the callback
    /// being waited for, the same deadlock class fixed once already in this
    /// file (see `runToCompletion`'s doc comment). Spinning the run loop lets
    /// main-actor work actually execute while this call still reads as
    /// synchronous to its caller.
    private static func runAsync(_ work: @escaping () async -> Void) {
        var finished = false
        Task {
            await work()
            finished = true
        }
        let deadline = Date().addingTimeInterval(10)
        while !finished && Date() < deadline {
            RunLoop.main.run(until: Date().addingTimeInterval(0.01))
        }
    }
}
