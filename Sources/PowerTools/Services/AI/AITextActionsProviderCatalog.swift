// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 PowerTools AI contributors

import Foundation

/// Which AI backend text actions currently use. Persisted by rawValue in
/// `DefaultsKey.aiTextActionsProvider`; `.onDevice` is the default so a
/// fresh install with Apple Intelligence available needs no setup, matching
/// PRIVACY.md's "AI is off until you turn it on" / on-device-first promise.
enum AITextActionsProviderKind: String, CaseIterable, Identifiable {
    case onDevice = "on-device"
    case deepseek
    case openai
    case anthropic
    case custom
    case localServer = "local-server"

    var id: String { rawValue }
}

/// Everything about one entry in the provider picker that doesn't depend on
/// what the person typed into a settings field: its Keychain/`AIProvider` id,
/// whether it needs a key or an editable endpoint/model, and its privacy
/// policy link. The settings view reads this to decide what controls to
/// show; `AITextActionsProviderFactory` reads it to build the right
/// `AIProvider`.
struct AITextActionsProviderOption {
    let kind: AITextActionsProviderKind
    /// The `AIProvider.id` / Keychain account this option's key is stored
    /// under. Fixed per kind, not per endpoint - `.custom` has exactly one
    /// key slot, so switching its endpoint reuses the same stored key.
    let providerID: String
    let defaultEndpoint: URL?
    let defaultModel: String?
    let requiresKey: Bool
    let endpointIsEditable: Bool
    let modelIsEditable: Bool
    /// Where this provider's own privacy policy lives - shown before a
    /// request leaves the Mac, per PRIVACY.md's promise that "Settings links
    /// to its privacy policy". `.custom` and `.localServer` point at this
    /// project's own AI privacy section instead, since neither names a
    /// single company whose policy applies.
    let privacyURL: URL
    /// Whether a request to this provider stays on the Mac. `.localServer` is
    /// `.local` despite being HTTP - a loopback-only address never leaves the
    /// Mac, matching PRIVACY.md's "With a model server on this Mac" section.
    let boundary: AIContextManifest.Boundary
}

enum AITextActionsProviderCatalog {
    /// This project's own AI privacy section, for options where no single
    /// third party's policy applies (a self-hosted or unnamed endpoint).
    /// Verified live: docs/PRIVACY.md is committed at this path on `main`.
    static let ownPrivacyURL = URL(string: "\(AppInfo.repositoryURL.absoluteString)/blob/main/docs/PRIVACY.md#ai")!

    // Third-party privacy policy links below were checked live before being
    // hardcoded, the same discipline `AppInfo.swift` applies to its own
    // outward-facing URLs: a wrong link is worse than an honest placeholder.
    static let onDevice = AITextActionsProviderOption(
        kind: .onDevice, providerID: "apple-on-device", defaultEndpoint: nil, defaultModel: nil,
        requiresKey: false, endpointIsEditable: false, modelIsEditable: false,
        privacyURL: URL(string: "https://www.apple.com/legal/privacy/")!, boundary: .local
    )
    static let deepseek = AITextActionsProviderOption(
        kind: .deepseek, providerID: "deepseek",
        defaultEndpoint: URL(string: "https://api.deepseek.com/v1")!, defaultModel: "deepseek-chat",
        requiresKey: true, endpointIsEditable: false, modelIsEditable: true,
        privacyURL: URL(string: "https://cdn.deepseek.com/policies/en-US/deepseek-privacy-policy.html")!,
        boundary: .remote
    )
    static let openai = AITextActionsProviderOption(
        kind: .openai, providerID: "openai",
        defaultEndpoint: URL(string: "https://api.openai.com/v1")!, defaultModel: "gpt-4o-mini",
        requiresKey: true, endpointIsEditable: false, modelIsEditable: true,
        privacyURL: URL(string: "https://openai.com/policies/")!, boundary: .remote
    )
    static let anthropic = AITextActionsProviderOption(
        kind: .anthropic, providerID: "anthropic",
        defaultEndpoint: URL(string: "https://api.anthropic.com")!, defaultModel: "claude-haiku-4-5-20251001",
        requiresKey: true, endpointIsEditable: false, modelIsEditable: true,
        privacyURL: URL(string: "https://www.anthropic.com/legal/privacy")!, boundary: .remote
    )
    static let custom = AITextActionsProviderOption(
        kind: .custom, providerID: "custom", defaultEndpoint: nil, defaultModel: nil,
        requiresKey: true, endpointIsEditable: true, modelIsEditable: true,
        privacyURL: ownPrivacyURL, boundary: .remote
    )
    static let localServer = AITextActionsProviderOption(
        kind: .localServer, providerID: "local-server",
        defaultEndpoint: URL(string: "http://localhost:11434/v1")!, defaultModel: nil,
        requiresKey: false, endpointIsEditable: true, modelIsEditable: true,
        privacyURL: ownPrivacyURL, boundary: .local
    )

    static let all: [AITextActionsProviderOption] = [onDevice, deepseek, openai, anthropic, custom, localServer]

    static func option(for kind: AITextActionsProviderKind) -> AITextActionsProviderOption {
        switch kind {
        case .onDevice: return onDevice
        case .deepseek: return deepseek
        case .openai: return openai
        case .anthropic: return anthropic
        case .custom: return custom
        case .localServer: return localServer
        }
    }

    /// The single source of this mapping - the settings picker and the
    /// context manifest both call this instead of each keeping their own
    /// switch over `AITextActionsProviderKind`.
    static func displayName(for kind: AITextActionsProviderKind, strings: AITextActionsFeatureStrings) -> String {
        switch kind {
        case .onDevice: return strings.providerOnDevice
        case .deepseek: return strings.providerDeepSeek
        case .openai: return strings.providerOpenAI
        case .anthropic: return strings.providerAnthropic
        case .custom: return strings.providerCustom
        case .localServer: return strings.providerLocalServer
        }
    }
}
