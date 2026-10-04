// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 PowerTools AI contributors

import Foundation

/// Roadmap slice 3.2: AI text actions on one chosen clipboard item. The rules
/// for what may be sent are executed; the menu and result panel that apply
/// them are checked as source shape, since they need a live panel and a
/// provider.
enum ClipboardTransformTests {
    static func run(_ suite: TestSuite) {
        policyChecks(suite)
        manifestChecks(suite)
        wiringChecks(suite)
    }

    private static let strings = AITextActionsFeatureStrings.enUS
    private static let limit = ClipboardTransformPolicy.maximumCharacters

    private static func text(_ value: String) -> ClipboardHistoryEntry {
        ClipboardHistoryEntry(text: value)
    }

    private static func policyChecks(_ suite: TestSuite) {
        let ordinary = text("Notes from Monday's planning call")
        suite.expect(ClipboardTransformPolicy.refusal(for: ordinary, boundary: .remote) == nil
                        && ClipboardTransformPolicy.refusal(for: ordinary, boundary: .local) == nil,
                     "an ordinary text clip may be sent to any provider")

        let image = ClipboardHistoryEntry(text: "", kind: .image, imageFile: "clip.png")
        let files = ClipboardHistoryEntry(text: "", kind: .files, filePaths: ["/tmp/a.txt"])
        suite.expect(ClipboardTransformPolicy.refusal(for: image, boundary: .local) == .notText
                        && ClipboardTransformPolicy.refusal(for: files, boundary: .local) == .notText,
                     "an image or a file clip is never sent as text")
        suite.expect(!ClipboardTransformPolicy.offersTransform(for: image)
                        && !ClipboardTransformPolicy.offersTransform(for: files)
                        && !ClipboardTransformPolicy.offersTransform(for: text(" \n\t "))
                        && ClipboardTransformPolicy.offersTransform(for: ordinary),
                     "Transform is offered only on clips that have text to send")
        suite.expect(ClipboardTransformPolicy.refusal(for: text(" \n\t "), boundary: .local) == .empty,
                     "a blank clip is refused")

        let atLimit = text(String(repeating: "a", count: limit))
        let overLimit = text(String(repeating: "a", count: limit + 1))
        suite.expect(ClipboardTransformPolicy.refusal(for: atLimit, boundary: .remote) == nil,
                     "a clip exactly at the limit may be sent")
        suite.expect(ClipboardTransformPolicy.refusal(for: overLimit, boundary: .local) == .tooLong
                        && ClipboardTransformPolicy.refusal(for: overLimit, boundary: .remote) == .tooLong,
                     "a clip over the limit is refused, whichever provider is chosen")
        suite.expect(ClipboardTransformPolicy.refusal(for: text("\n\n" + String(repeating: "a", count: limit) + "  \n"),
                                                      boundary: .local) == nil,
                     "surrounding whitespace does not count toward the limit")
        suite.expect(limit < ClipboardHistoryEditing.maxCharacters,
                     "the limit is well under what the history itself will store, so a huge clip is never sent whole")

        let secret = text("my password is hunter2")
        suite.expect(ClipboardTransformPolicy.refusal(for: secret, boundary: .remote) == .looksSensitiveForRemote,
                     "a clip that looks like a secret is never sent to a cloud provider")
        suite.expect(ClipboardTransformPolicy.refusal(for: secret, boundary: .local) == nil,
                     "the same clip may still be transformed on this Mac, where nothing leaves it")

        let refusals: [ClipboardTransformPolicy.Refusal] = [.notText, .empty, .tooLong, .looksSensitiveForRemote]
        let messages = refusals.map { $0.message(strings: strings) }
        suite.expect(messages.allSatisfy { !$0.isEmpty }
                        && ClipboardTransformPolicy.Refusal.tooLong.message(strings: strings).contains(String(limit))
                        && messages[2] != messages[3],
                     "each reason a clip was not sent is worded, and the length message states the real limit")
    }

    private static func manifestChecks(_ suite: TestSuite) {
        let body = "Quarterly numbers, draft two"
        let manifest = AIContextManifestBuilder.clipboardItem(
            body, option: AITextActionsProviderCatalog.onDevice, strings: strings)
        suite.expect(manifest.contentType != AIContextManifestBuilder.selectedTextContentType
                        && manifest.contentType != AIContextManifestBuilder.healthSnapshotContentType
                        && manifest.contentType == AIContextManifestBuilder.clipboardItemContentType,
                     "a clipboard item is its own content type, so it gets its own first-send preview")
        suite.expect(manifest.approximateSizeBytes == body.utf8.count && manifest.itemCount == 1
                        && manifest.contentTypeLabel == strings.previewContentTypeClipboardItem
                        && manifest.retentionNote == strings.previewRetentionLocal,
                     "the clip preview states its real size, and that an on-device request stays on this Mac")
    }

    private static func source(_ path: String) -> String {
        ((try? String(contentsOfFile: path, encoding: .utf8)) ?? "")
            .components(separatedBy: "\n")
            .filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//") }
            .joined(separator: "\n")
    }

    private static func wiringChecks(_ suite: TestSuite) {
        let controller = source("Sources/PowerTools/Services/QuickTools/AITextActionPanelController.swift")
        suite.expect(!controller.isEmpty, "the text action panel source is readable for its clipboard checks")

        let refusalCall = "let refusal = ClipboardTransformPolicy.refusal(for: entry, boundary: option.boundary) {"
        if let refusalAt = controller.range(of: refusalCall)?.lowerBound,
           let providerAt = controller.range(of: "AITextActionsProviderFactory.makeProvider(")?.lowerBound {
            suite.expect(refusalAt < providerAt,
                         "a clip that must not be sent is refused before any provider is built or asked, and before the first-send preview")
        } else {
            suite.expect(false, "the clipboard refusal and the provider lookup are both found in the panel controller")
        }
        suite.expect(controller.contains("AIContextManifestBuilder.clipboardItem(text, option: option, strings: strings)"),
                     "a clip is previewed as a clipboard item, not as selected text")
        suite.expect(controller.contains("if case .selection = self { return true }\n            return false"),
                     "Replace is offered for a Command Bar selection only, never for a clip, which has no text field to replace into")
        suite.expect(controller.contains("if showsReplace {"),
                     "the result panel hides Replace when it is not allowed")
        suite.expect(!controller.contains("ClipboardHistoryService") && !controller.contains("ClipboardHistoryEntry("),
                     "the transform cannot reach the clip history, so the original is never changed or removed: the answer reaches it only by being copied")

        let quickPanel = source("Sources/PowerTools/UI/MenuPanel/ClipboardQuickPanelView.swift")
        suite.expect(quickPanel.contains("if AppFeature.aiTextActions.isAvailable, ClipboardTransformPolicy.offersTransform(for: entry) {"),
                     "Transform appears only once AI text actions is installed, and only on text clips")
        suite.expect(quickPanel.contains("history.hideHistoryWindow()\n                    AITextActionPanelController.shared.runOnClipboardItem(kind, entry: entry)"),
                     "choosing an action closes the quick panel and runs it on exactly the clip it was chosen from")
    }
}
