// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 PowerTools AI contributors

import AppKit
import Carbon.HIToolbox
import SwiftUI

/// Runs one AI text action (rewrite, shorten, proofread, summarise,
/// translate) on a Command Bar selection and shows its result: a small
/// floating panel near the pointer, shaped like `QRResultController`'s -
/// borderless, non-activating, dismissed by Escape or an outside click - with
/// Copy, Replace and Cancel. The only entry point the Command Bar's AI rows
/// use.
final class AITextActionPanelController {
    static let shared = AITextActionPanelController()

    private var panel: AITextActionPanel?
    private var keyMonitor: Any?
    private var localMonitor: Any?
    private var globalMonitor: Any?
    private let request = AICancellableRequest()

    private init() {}

    /// `text` is the selection the row captured when it ran, not re-read
    /// later - the Command Bar has already closed by the time this shows, so
    /// there is nothing left to re-read from.
    func run(_ kind: AITextActionKind, text: String) {
        guard Thread.isMainThread else {
            DispatchQueue.main.async { self.run(kind, text: text) }
            return
        }
        let strings = FeatureStrings.aiTextActions(L10n.shared.language)
        let title = kind.title(strings: strings)
        let configuration = AITextActionsProviderConfiguration.current()
        let option = AITextActionsProviderCatalog.option(for: configuration.kind)

        guard let provider = AITextActionsProviderFactory.makeProvider(for: configuration) else {
            let model = AITextActionPanelModel(phase: .failed(strings.reasonNoProviderConfigured))
            present(title: title, model: model)
            return
        }
        if case .unavailable(let reason) = provider.currentAvailability() {
            let model = AITextActionPanelModel(
                phase: .failed(AITextActionsProviderFactory.describe(reason, strings: strings)))
            present(title: title, model: model)
            return
        }

        let manifest = AIContextManifestBuilder.selectedText(text, option: option, strings: strings)
        if AIPreSendPreviewTracker.hasShownPreview(contentType: manifest.contentType, providerID: manifest.providerID) {
            let model = AITextActionPanelModel(phase: .running(text: ""))
            present(title: title, model: model)
            start(kind: kind, text: text, provider: provider, model: model, strings: strings)
        } else {
            let model = AITextActionPanelModel(phase: .previewing(manifest))
            present(title: title, model: model, onSend: { [weak self] in
                AIPreSendPreviewTracker.recordPreviewShown(
                    contentType: manifest.contentType, providerID: manifest.providerID)
                model.phase = .running(text: "")
                self?.relayout()
                self?.start(kind: kind, text: text, provider: provider, model: model, strings: strings)
            })
        }
    }

    private func start(
        kind: AITextActionKind, text: String, provider: AIProvider,
        model: AITextActionPanelModel, strings: AITextActionsFeatureStrings
    ) {
        let instructions = kind.instructions(targetLanguage: L10n.shared.language)
        request.run(
            provider.streamText(instructions: instructions, prompt: text, maxOutputTokens: nil),
            onUpdate: { [weak self] partial in
                model.phase = .running(text: partial)
                self?.relayout()
            },
            onFinish: { [weak self] result in
                switch result {
                case .success:
                    if case .running(let finalText) = model.phase {
                        model.phase = .finished(text: finalText)
                    }
                case .failure(let error):
                    let generationError = error as? AIGenerationError ?? .other(String(describing: error))
                    model.phase = .failed(AITextActionsProviderFactory.describe(generationError, strings: strings))
                }
                self?.relayout()
            }
        )
    }

    // MARK: - Panel lifecycle

    private func present(title: String, model: AITextActionPanelModel, onSend: @escaping () -> Void = {}) {
        close()
        let strings = FeatureStrings.aiTextActions(L10n.shared.language)
        let content = AnyView(AITextActionPanelHostView(
            model: model, title: title, strings: strings,
            onSend: onSend,
            onCancelPreview: { [weak self] in self?.close() },
            onCancelRunning: { [weak self] in self?.cancelRunning() },
            onCopy: { [weak self] text in self?.copy(text) },
            onReplace: { [weak self] text in self?.replace(text) }
        ))
        let host = NSHostingController(rootView: content)
        host.view.layoutSubtreeIfNeeded()
        let size = host.view.fittingSize

        let panel = AITextActionPanel(
            contentRect: CGRect(origin: .zero, size: size),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false)
        panel.contentViewController = host
        panel.isReleasedWhenClosed = false
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.hidesOnDeactivate = false
        panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary,
                                    .transient, .ignoresCycle]

        let visible = NSScreen.pointerVisibleFrame
        let pointer = NSEvent.mouseLocation
        var origin = CGPoint(x: pointer.x - size.width / 2, y: pointer.y - size.height - 18)
        origin.x = min(max(origin.x, visible.minX + 12), visible.maxX - size.width - 12)
        origin.y = min(max(origin.y, visible.minY + 12), visible.maxY - size.height - 12)
        panel.setFrame(CGRect(origin: origin, size: size), display: false)
        self.panel = panel

        installMonitors(for: panel)
        panel.alphaValue = 0
        panel.orderFrontRegardless()
        panel.makeKey()
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.12
            panel.animator().alphaValue = 1
        }
    }

    /// Re-measures the hosted SwiftUI content after a phase change (preview
    /// to running, or a growing streamed answer) and resizes the panel,
    /// anchored at its top edge so it grows downward rather than jumping.
    private func relayout() {
        guard let panel, let host = panel.contentViewController else { return }
        host.view.layoutSubtreeIfNeeded()
        let size = host.view.fittingSize
        guard size != panel.frame.size else { return }
        let topY = panel.frame.origin.y + panel.frame.height
        var frame = panel.frame
        frame.size = size
        frame.origin.y = topY - size.height
        panel.setFrame(frame, display: true, animate: false)
    }

    private func cancelRunning() {
        request.cancel()
        close()
    }

    private func copy(_ text: String) {
        close()
        GeneralPasteboardAccess.shared.async({
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(text, forType: .string)
        }, then: {
            QuickToolHUD.show(icon: "doc.on.doc", message: text)
        })
    }

    private func replace(_ text: String) {
        close()
        CommandBarCatalog.typeAtCursor(text)
    }

    func close() {
        request.cancel()
        if let keyMonitor {
            NSEvent.removeMonitor(keyMonitor)
            self.keyMonitor = nil
        }
        if let localMonitor {
            NSEvent.removeMonitor(localMonitor)
            self.localMonitor = nil
        }
        if let globalMonitor {
            NSEvent.removeMonitor(globalMonitor)
            self.globalMonitor = nil
        }
        panel?.orderOut(nil)
        panel = nil
    }

    private func installMonitors(for panel: NSPanel) {
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard event.window === panel else { return event }
            if Int(event.keyCode) == kVK_Escape {
                self?.close()
                return nil
            }
            return event
        }
        localMonitor = NSEvent.addLocalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            if event.window !== self?.panel { self?.close() }
            return event
        }
        globalMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            self?.close()
        }
    }
}

/// A non-activating panel that can still take key focus so its buttons and
/// selectable text respond without bringing the whole app forward - the
/// frontmost app stays whatever the person was typing in, which
/// `CommandBarCatalog.typeAtCursor` depends on for Replace to work at all.
private final class AITextActionPanel: NSPanel {
    override var canBecomeKey: Bool { true }
}

private final class AITextActionPanelModel: ObservableObject {
    enum Phase {
        case previewing(AIContextManifest)
        case running(text: String)
        case finished(text: String)
        case failed(String)
    }

    @Published var phase: Phase

    init(phase: Phase) {
        self.phase = phase
    }
}

private struct AITextActionPanelHostView: View {
    @ObservedObject var model: AITextActionPanelModel
    let title: String
    let strings: AITextActionsFeatureStrings
    let onSend: () -> Void
    let onCancelPreview: () -> Void
    let onCancelRunning: () -> Void
    let onCopy: (String) -> Void
    let onReplace: (String) -> Void

    var body: some View {
        switch model.phase {
        case .previewing(let manifest):
            AIPreSendPreviewSheet(manifest: manifest, onSend: onSend, onCancel: onCancelPreview)
        case .running(let text):
            AITextActionResultView(title: title, strings: strings, text: text,
                                   isRunning: true, errorMessage: nil,
                                   onCopy: onCopy, onReplace: onReplace, onCancel: onCancelRunning)
        case .finished(let text):
            AITextActionResultView(title: title, strings: strings, text: text,
                                   isRunning: false, errorMessage: nil,
                                   onCopy: onCopy, onReplace: onReplace, onCancel: onCancelRunning)
        case .failed(let message):
            AITextActionResultView(title: title, strings: strings, text: "",
                                   isRunning: false, errorMessage: message,
                                   onCopy: onCopy, onReplace: onReplace, onCancel: onCancelRunning)
        }
    }
}

private struct AITextActionResultView: View {
    let title: String
    let strings: AITextActionsFeatureStrings
    let text: String
    let isRunning: Bool
    let errorMessage: String?
    let onCopy: (String) -> Void
    let onReplace: (String) -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 7) {
                Image(systemName: "wand.and.stars")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.accentColor)
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                Spacer(minLength: 0)
                if isRunning {
                    ProgressView().controlSize(.small)
                }
            }

            if let errorMessage {
                Text(errorMessage)
                    .font(.system(size: 12.5))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                ScrollView(.vertical) {
                    Text(text.isEmpty ? strings.resultWorkingLabel : text)
                        .font(.system(size: 12.5))
                        .textSelection(.enabled)
                        .foregroundStyle(text.isEmpty ? .secondary : .primary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(10)
                }
                .frame(minHeight: 44, maxHeight: 220)
                .fixedSize(horizontal: false, vertical: true)
                .background(Color.primary.opacity(0.05),
                            in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .strokeBorder(Color.primary.opacity(0.1), lineWidth: 1)
                )
            }

            HStack(spacing: 8) {
                Spacer(minLength: 0)
                if isRunning {
                    Button(strings.resultCancelButton, action: onCancel)
                        .keyboardShortcut(.cancelAction)
                } else if errorMessage == nil {
                    Button(strings.resultCopyButton) { onCopy(text) }
                        .buttonStyle(.bordered)
                    Button(strings.resultReplaceButton) { onReplace(text) }
                        .buttonStyle(.borderedProminent)
                        .keyboardShortcut(.defaultAction)
                }
            }
        }
        .padding(16)
        .frame(width: 360)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.1), lineWidth: 1)
        )
    }
}
