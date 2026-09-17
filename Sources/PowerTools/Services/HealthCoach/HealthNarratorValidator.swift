// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 PowerTools AI contributors

import Foundation

/// Checks one raw model reply against the evidence that justified asking,
/// before anything derived from it reaches the header. A reply that fails
/// any check here is discarded outright — the caller falls back to
/// `HealthNarrationTemplate`, never a partially-trusted answer
/// (`docs/ai-health-coach/README.md`, sections 3.4 and 5).
enum HealthNarratorValidator {
    struct Parsed: Equatable {
        let headline: String
        let bullets: [String]
    }

    static let maxHeadlineLength = 90
    static let maxBulletLength = 140
    static let maxBullets = 3

    /// A percentage the model states must land within this many points of
    /// some percentage actually in the evidence — close enough for rounding
    /// (the model sees "42%", nothing stops it saying "around 40%").
    static let percentTolerance = 5

    static func parse(_ raw: String) -> Parsed? {
        let lines = raw.split(separator: "\n", omittingEmptySubsequences: false).map {
            $0.trimmingCharacters(in: .whitespaces)
        }
        guard let headlineLine = lines.first(where: { $0.lowercased().hasPrefix("headline:") }) else { return nil }
        let headline = String(headlineLine.dropFirst("headline:".count)).trimmingCharacters(in: .whitespaces)
        let bullets = lines
            .filter { $0.hasPrefix("-") }
            .map { String($0.dropFirst()).trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        // The fixed instructions always ask for a headline plus bullets in
        // this exact shape; a reply with neither didn't follow it at all,
        // which is itself reason enough to fall back to the template rather
        // than show a headline with nothing behind it.
        guard !headline.isEmpty, !bullets.isEmpty else { return nil }
        return Parsed(headline: headline, bullets: bullets)
    }

    static func validate(_ raw: String, findings: [HealthFinding]) -> Parsed? {
        guard let parsed = parse(raw) else { return nil }
        guard parsed.headline.count <= maxHeadlineLength else { return nil }
        guard parsed.bullets.count <= maxBullets else { return nil }
        guard parsed.bullets.allSatisfy({ $0.count <= maxBulletLength }) else { return nil }

        let fullText = ([parsed.headline] + parsed.bullets).joined(separator: "\n")
        guard !containsURLOrCommand(fullText) else { return nil }
        guard !claimsAllIsWellDuringACritical(parsed.headline, findings: findings) else { return nil }
        guard !namesAnAppNotInEvidence(fullText, findings: findings) else { return nil }
        guard !citesAPercentNotInEvidence(fullText, findings: findings) else { return nil }

        return parsed
    }

    private static func containsURLOrCommand(_ text: String) -> Bool {
        let lowered = text.lowercased()
        let markers = ["http://", "https://", "www.", "sudo ", "rm -rf", "$(", "`", " && ", " | "]
        return markers.contains { lowered.contains($0) }
    }

    private static func claimsAllIsWellDuringACritical(_ headline: String, findings: [HealthFinding]) -> Bool {
        guard findings.contains(where: { $0.severity == .critical }) else { return false }
        let lowered = headline.lowercased()
        let allIsWellPhrases = ["everything is fine", "everything looks good", "no issues", "all good", "all clear"]
        return allIsWellPhrases.contains { lowered.contains($0) }
    }

    /// Every app/process/device name the model could truthfully cite,
    /// sanitised the same way the prompt builder sanitised it going in, so
    /// the comparison is apples to apples with what the model actually saw.
    private static func evidenceNames(_ findings: [HealthFinding]) -> Set<String> {
        var names: Set<String> = []
        func add(_ name: String) { names.insert(HealthNarratorPrompt.sanitizeName(name).lowercased()) }
        for finding in findings {
            switch finding {
            case .thermal(_, let topCPUApp):
                if let topCPUApp { add(topCPUApp.name) }
            case .memoryPressureCritical(_, _, _, let topApps), .memoryPressureWarning(_, _, _, let topApps):
                topApps.forEach { add($0.name) }
            case .diskLow(let device, _):
                add(device.name)
            case .memoryHog(let app, _, _):
                add(app.name)
            case .cpuSustained(_, _, let topApps):
                topApps.forEach { add($0.name) }
            case .knownActivity(let sighting):
                add(sighting.appName)
            case .batteryLow, .swapGrowth, .updateAvailable:
                break
            }
        }
        return names
    }

    /// A capitalised word or run of capitalised words (`Xcode`, `Visual
    /// Studio Code`) is the shape an app name takes in prose; anything of
    /// that shape must match a name the evidence actually supplied, or a
    /// word ordinary English capitalises on its own (a sentence's first
    /// word, "I", a handful of common nouns). This is a best-effort textual
    /// net, not real language understanding: a single capitalised common
    /// word can never be told apart from a one-word app name by shape
    /// alone, so a multi-word run (which ordinary advice-style prose rarely
    /// produces by accident, but a real multi-word app name often is —
    /// "Visual Studio Code") is treated as the stronger signal and is
    /// always checked against the evidence, common-word or not.
    private static func namesAnAppNotInEvidence(_ text: String, findings: [HealthFinding]) -> Bool {
        let allowed = evidenceNames(findings).union(alwaysAllowedWords)
        // A literal space only, not `\s`: NSRegularExpression's `\s` also
        // matches the newline between two bullets, which glued the last
        // word of one bullet to the first word of the next into a single
        // bogus "multi-word" candidate ("RAM\nConsider") that matched no
        // single-word allow list and was wrongly rejected as invented.
        guard let regex = try? NSRegularExpression(pattern: "\\b[A-Z][A-Za-z0-9]*(?:[ ][A-Z][A-Za-z0-9]*)*\\b") else {
            return false
        }
        let matches = regex.matches(in: text, range: NSRange(text.startIndex..., in: text))
        for match in matches {
            guard let range = Range(match.range, in: text) else { continue }
            let candidate = String(text[range]).lowercased()
            if allowed.contains(candidate) { continue }
            if !candidate.contains(" "), commonCapitalisedWords.contains(candidate) { continue }
            return true
        }
        return false
    }

    private static let alwaysAllowedWords: Set<String> = [
        "mac", "cpu", "gpu", "ram", "health coach", "powertools", "gb", "mb",
    ]

    /// Common English words this validator lets stand capitalised without
    /// treating them as an app-name claim — articles, pronouns, connectors,
    /// and the verbs and nouns advice-style sentences about a Mac's memory,
    /// CPU, disk and battery tend to use. Not exhaustive; broadened here
    /// specifically for the vocabulary this feature's own sentences use.
    private static let commonCapitalisedWords: Set<String> = [
        "the", "your", "you", "a", "an", "this", "that", "these", "those", "it", "its", "i",
        "detail", "headline", "data", "everything", "nothing", "something", "someone",
        "if", "when", "while", "once", "after", "before", "since", "because", "so", "and", "but", "or",
        "there", "here", "now", "still", "also", "consider", "try", "check", "close", "closing",
        "restart", "restarting", "quit", "quitting", "open", "opening", "use", "using", "free", "freeing",
        "clear", "clearing", "turn", "keep", "keeping", "wait", "waiting", "review", "reviewing",
        "reduce", "reducing", "stop", "stopping", "empty", "emptying", "save", "saving", "plug",
        "mac", "macbook", "memory", "storage", "disk", "battery", "cpu", "gpu", "ram", "app", "apps",
        "process", "processes", "activity", "update", "updates", "system", "background", "build",
        "spotlight", "time", "machine",
    ]

    /// Every whole-number percentage the model states (`"42%"`) must be
    /// within tolerance of one the evidence actually carries — the numeric
    /// counterpart to `namesAnAppNotInEvidence`. Non-percentage numbers
    /// (byte sizes, process counts, seconds) are already formatted by
    /// `HealthNarratorPrompt` from the same evidence values, so a model
    /// that merely repeats them verbatim needs no separate check; this
    /// catches an invented severity/figure stated as a percent specifically,
    /// the shape most likely to be quoted loosely.
    private static func citesAPercentNotInEvidence(_ text: String, findings: [HealthFinding]) -> Bool {
        guard let regex = try? NSRegularExpression(pattern: "(\\d+)%") else { return false }
        let matches = regex.matches(in: text, range: NSRange(text.startIndex..., in: text))
        guard !matches.isEmpty else { return false }
        let evidencePercents = evidencePercentages(findings)
        guard !evidencePercents.isEmpty else { return !matches.isEmpty }
        for match in matches {
            guard let range = Range(match.range(at: 1), in: text), let value = Int(text[range]) else { continue }
            let matchesEvidence = evidencePercents.contains { abs($0 - value) <= percentTolerance }
            if !matchesEvidence { return true }
        }
        return false
    }

    private static func evidencePercentages(_ findings: [HealthFinding]) -> [Int] {
        var values: [Int] = []
        for finding in findings {
            switch finding {
            case .batteryLow(let chargePercent, let thresholdPercent):
                values.append(contentsOf: [chargePercent, thresholdPercent])
            case .memoryHog(_, let percentOfTotal, let thresholdPercent):
                values.append(contentsOf: [Int(percentOfTotal.rounded()), thresholdPercent])
            case .cpuSustained(let usage, let thresholdPercent, let topApps):
                values.append(contentsOf: [Int((usage * 100).rounded()), thresholdPercent])
                values.append(contentsOf: topApps.map { Int($0.value.rounded()) })
            case .diskLow(_, let thresholdPercent):
                values.append(thresholdPercent)
            case .knownActivity(let sighting) where !sighting.valueIsMemoryBytes:
                values.append(Int(sighting.appValue.rounded()))
            default:
                break
            }
        }
        return values
    }
}
