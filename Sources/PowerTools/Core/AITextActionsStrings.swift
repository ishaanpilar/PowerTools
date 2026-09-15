// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 PowerTools AI contributors

import Foundation

/// Localized strings for AI text actions. English only for now (roadmap D5);
/// every other language repeats the English text until translation resumes.
struct AITextActionsFeatureStrings {
    let pageTitle: String
    let hubDescription: String
    let settingsIntro: String
    let comingSoonTitle: String
    let comingSoonBody: String

    let providerSectionTitle: String
    let providerOnDevice: String
    let providerDeepSeek: String
    let providerOpenAI: String
    let providerAnthropic: String
    let providerCustom: String
    let providerLocalServer: String

    let endpointSectionTitle: String
    let endpointPlaceholder: String
    let modelSectionTitle: String
    let modelPlaceholder: String

    let apiKeySectionTitle: String
    let apiKeyPlaceholderEmpty: String
    let apiKeyPlaceholderSaved: String
    let saveKeyButton: String
    let removeKeyButton: String

    let testConnectionButton: String
    let testConnectionSuccess: String
    let privacyPolicyLink: String

    let reasonRequiresNewerMacOS: String
    let reasonDeviceNotEligible: String
    let reasonAppleIntelligenceNotEnabled: String
    let reasonModelNotReady: String
    let reasonNoProviderConfigured: String
    let reasonEndpointNotAllowed: String
    let errorInvalidKey: String
    let errorOffline: String
    let errorTimeout: String
    let errorRateLimited: String
    let errorHTTPFormat: String
    let errorGeneric: String

    let previewContentTypeSelectedText: String
    let previewRetentionLocal: String
    let previewRetentionRemote: String
    let previewTitle: String
    let previewIntro: String
    let previewFieldContent: String
    let previewFieldItemCount: String
    let previewFieldSize: String
    let previewFieldDestination: String
    let previewFieldRetention: String
    let previewCancelButton: String
    let previewSendButton: String
    let previewDontAskAgainNote: String

    let actionRewriteTitle: String
    let actionShortenTitle: String
    let actionProofreadTitle: String
    let actionSummariseTitle: String
    let actionTranslateTitle: String
    let actionRowSubtitle: String

    let resultWorkingLabel: String
    let resultCopyButton: String
    let resultReplaceButton: String
    let resultCancelButton: String
}

extension FeatureStrings {
    static func aiTextActions(_ language: AppLanguage) -> AITextActionsFeatureStrings {
        switch language {
        case .enUS: return .enUS
        case .ptBR: return .enUS
        case .tr: return .enUS
        case .ru: return .enUS
        case .es: return .enUS
        case .de: return .enUS
        case .fr: return .enUS
        case .it: return .enUS
        case .ja: return .enUS
        case .ko: return .enUS
        case .zhHans: return .enUS
        case .zhTW: return .enUS
        case .zhHK: return .enUS
        }
    }
}

extension AITextActionsFeatureStrings {
    static let enUS = AITextActionsFeatureStrings(
        pageTitle: "AI text actions",
        hubDescription: "Rewrite, shorten or translate the text you select, on this Mac or with a provider you choose",
        settingsIntro: "Select text anywhere and rewrite, shorten, proofread, summarise or translate it from the Command Bar. Nothing is sent anywhere until you choose a provider.",
        comingSoonTitle: "Actions not wired in yet",
        comingSoonBody: "Provider setup below is real, but rewrite, shorten, proofread, summarise and translate aren’t in the Command Bar yet. Nothing is sent until they ship.",

        providerSectionTitle: "Provider",
        providerOnDevice: "On this Mac (Apple Intelligence)",
        providerDeepSeek: "DeepSeek",
        providerOpenAI: "OpenAI",
        providerAnthropic: "Anthropic",
        providerCustom: "Custom (OpenAI-compatible)",
        providerLocalServer: "Local server (Ollama, LM Studio)",

        endpointSectionTitle: "Endpoint",
        endpointPlaceholder: "https://your-server/v1",
        modelSectionTitle: "Model",
        modelPlaceholder: "Model name",

        apiKeySectionTitle: "API key",
        apiKeyPlaceholderEmpty: "Paste your API key",
        apiKeyPlaceholderSaved: "Key saved. Enter a new one to replace it.",
        saveKeyButton: "Save key",
        removeKeyButton: "Remove key",

        testConnectionButton: "Test connection",
        testConnectionSuccess: "Connected",
        privacyPolicyLink: "Privacy policy",

        reasonRequiresNewerMacOS: "Requires macOS 26 or later",
        reasonDeviceNotEligible: "This Mac doesn’t support Apple Intelligence",
        reasonAppleIntelligenceNotEnabled: "Turn on Apple Intelligence in System Settings",
        reasonModelNotReady: "The on-device model is still downloading",
        reasonNoProviderConfigured: "Add an API key to use this provider",
        reasonEndpointNotAllowed: "This address isn’t allowed. Use HTTPS, or a local address for a server on this Mac.",
        errorInvalidKey: "That API key was rejected",
        errorOffline: "No internet connection",
        errorTimeout: "The request timed out",
        errorRateLimited: "Rate limited. Try again shortly.",
        errorHTTPFormat: "The provider returned an error (status %1$d)",
        errorGeneric: "Something went wrong",

        previewContentTypeSelectedText: "Selected text",
        previewRetentionLocal: "Processed on this Mac. Not kept anywhere, not sent anywhere.",
        previewRetentionRemote: "Governed by the provider’s own policy. See the privacy link below.",
        previewTitle: "Before this is sent",
        previewIntro: "This is the first time selected text is going to this provider. You’ll see this once per provider; after that it sends right away.",
        previewFieldContent: "Content",
        previewFieldItemCount: "Items",
        previewFieldSize: "Size",
        previewFieldDestination: "Sent to",
        previewFieldRetention: "Retention",
        previewCancelButton: "Cancel",
        previewSendButton: "Send",
        previewDontAskAgainNote: "You won’t see this again for this provider",

        actionRewriteTitle: "Rewrite",
        actionShortenTitle: "Shorten",
        actionProofreadTitle: "Proofread",
        actionSummariseTitle: "Summarise",
        actionTranslateTitle: "Translate",
        actionRowSubtitle: "AI text action",

        resultWorkingLabel: "Working…",
        resultCopyButton: "Copy",
        resultReplaceButton: "Replace",
        resultCancelButton: "Cancel"
    )
}
