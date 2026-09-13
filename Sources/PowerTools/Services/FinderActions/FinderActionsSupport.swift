// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 PowerTools contributors

import Foundation
import UniformTypeIdentifiers

/// Everything the Finder extension and the app have to agree on. This file is
/// compiled into both (and into the tests), so it stays pure Foundation: no
/// AppKit, no app singletons.
///
/// The extension runs sandboxed inside Finder and cannot touch the files it is
/// shown. It only draws the menu and hands the chosen action over: it writes a
/// request file into a folder only it and the app can reach, then opens the
/// app's URL naming that request. A URL on its own does nothing, so a web page
/// or another app that opens the same scheme cannot make the app act on files.
enum FinderAction: String, CaseIterable, Codable {
    case copyFullPath, copyName, copyFolderPath
    case copyToShelf, openTerminal
    case newTextFile, newMarkdownFile, newEmptyFile
    case compressZip, moveTo, copyTo, batchRename, deletePermanently
    case convertJPEG, convertPNG, convertHEIC, convertPDF, resizeImages, extractText, copyImage
    case editVideo, compressVideoSmall, compressVideoEmail, compressVideoCustom, makeGIF
    case uninstallApp, installDiskImage
}

/// Submenus of the PowerTools menu. Their titles travel in the configuration
/// like the action titles do.
enum FinderMenuGroup: String, CaseIterable, Codable {
    case copyPath, newFile, convertImage, compressVideo
}

enum FinderMenuEntry: Equatable {
    case action(FinderAction)
    case submenu(FinderMenuGroup, [FinderAction])
    case separator
}

enum FinderItemKind: Equatable {
    case folder, image, video, application, diskImage, other
}

/// What the app publishes for the extension: whether the menu shows at all,
/// its localized titles, and which actions the installed features can run.
struct FinderMenuConfiguration: Codable, Equatable {
    static let currentVersion = 1

    var version: Int
    var rootTitle: String
    var actionTitles: [String: String]
    var groupTitles: [String: String]
    var availableActions: [FinderAction]

    func title(for action: FinderAction) -> String? {
        actionTitles[action.rawValue].flatMap { $0.isEmpty ? nil : $0 }
    }

    func title(for group: FinderMenuGroup) -> String? {
        groupTitles[group.rawValue].flatMap { $0.isEmpty ? nil : $0 }
    }
}

struct FinderActionRequest: Codable, Equatable {
    static let currentVersion = 1

    let version: Int
    let id: UUID
    let action: FinderAction
    let paths: [String]
    let createdAt: Date

    init(id: UUID = UUID(), action: FinderAction, paths: [String], createdAt: Date = Date()) {
        version = Self.currentVersion
        self.id = id
        self.action = action
        self.paths = paths
        self.createdAt = createdAt
    }
}

enum FinderActionsSupport {
    static let menuDirectoryName = "FinderMenu"
    static let requestsDirectoryName = "Requests"
    static let configurationFileName = "menu.json"
    static let requestHost = "run"
    /// A request is picked up within a moment of being written; anything older
    /// is a leftover from a run that never reached the app.
    static let maximumRequestAge: TimeInterval = 120
    static let maximumPaths = 5_000
    static let maximumRequestBytes = 8_000_000
    static let infoHostBundleIdentifierKey = "PowerToolsHostBundleIdentifier"
    static let infoURLSchemeKey = "PowerToolsFinderURLScheme"

    // MARK: Locations

    /// The one folder the extension's sandbox may write, relative to the
    /// user's home. build.sh writes the same string into the extension's
    /// entitlements, and a test holds the two to this function.
    static func sandboxExceptionPath(hostBundleIdentifier: String) -> String {
        "/Library/Application Support/\(hostBundleIdentifier)/\(menuDirectoryName)/"
    }

    static func menuDirectory(home: URL, hostBundleIdentifier: String) -> URL {
        home.appendingPathComponent("Library", isDirectory: true)
            .appendingPathComponent("Application Support", isDirectory: true)
            .appendingPathComponent(hostBundleIdentifier, isDirectory: true)
            .appendingPathComponent(menuDirectoryName, isDirectory: true)
    }

    static func requestsDirectory(home: URL, hostBundleIdentifier: String) -> URL {
        menuDirectory(home: home, hostBundleIdentifier: hostBundleIdentifier)
            .appendingPathComponent(requestsDirectoryName, isDirectory: true)
    }

    static func configurationURL(home: URL, hostBundleIdentifier: String) -> URL {
        menuDirectory(home: home, hostBundleIdentifier: hostBundleIdentifier)
            .appendingPathComponent(configurationFileName, isDirectory: false)
    }

    static func requestFileURL(in requestsDirectory: URL, id: UUID) -> URL {
        requestsDirectory.appendingPathComponent("\(id.uuidString).json", isDirectory: false)
    }

    // MARK: Hand-off

    static func requestURL(scheme: String, id: UUID) -> URL? {
        var components = URLComponents()
        components.scheme = scheme
        components.host = requestHost
        components.queryItems = [URLQueryItem(name: "id", value: id.uuidString)]
        return components.url
    }

    static func requestID(from url: URL, scheme: String) -> UUID? {
        guard url.scheme?.caseInsensitiveCompare(scheme) == .orderedSame,
              url.host == requestHost,
              let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems,
              items.count == 1, items[0].name == "id",
              let raw = items[0].value else { return nil }
        return UUID(uuidString: raw)
    }

    /// Decodes a request only when it is the one the URL named, was written a
    /// moment ago, and lists absolute paths the app can act on.
    static func validatedRequest(_ data: Data, expectedID: UUID, now: Date) -> FinderActionRequest? {
        guard data.count <= maximumRequestBytes,
              let request = try? JSONDecoder().decode(FinderActionRequest.self, from: data),
              request.version == FinderActionRequest.currentVersion,
              request.id == expectedID else { return nil }
        let age = now.timeIntervalSince(request.createdAt)
        guard age >= -5, age <= maximumRequestAge,
              !request.paths.isEmpty, request.paths.count <= maximumPaths,
              request.paths.allSatisfy({ $0.hasPrefix("/") && !$0.contains("\0") })
        else { return nil }
        return request
    }

    // MARK: Menu

    static func kind(of url: URL) -> FinderItemKind {
        let ext = url.pathExtension.lowercased()
        if ext == "app" { return .application }
        if ext == "dmg" { return .diskImage }
        if url.hasDirectoryPath { return .folder }
        guard !ext.isEmpty, let type = UTType(filenameExtension: ext) else { return .other }
        if type.conforms(to: .movie) { return .video }
        if type.conforms(to: .image) { return .image }
        return .other
    }

    /// The PowerTools submenu for a selection, or for a folder's background
    /// when `isContainer` is true. Actions missing from `available` are left
    /// out, and so is any submenu or separator they leave empty.
    static func menu(for urls: [URL], isContainer: Bool,
                     available: Set<FinderAction>) -> [FinderMenuEntry] {
        guard !urls.isEmpty else { return [] }
        var entries: [FinderMenuEntry]
        if isContainer {
            entries = [
                .submenu(.copyPath, [.copyFullPath, .copyName]),
                .action(.openTerminal),
                .submenu(.newFile, [.newTextFile, .newMarkdownFile, .newEmptyFile]),
            ]
        } else {
            let kinds = urls.map(kind(of:))
            let single = urls.count == 1
            entries = [
                .submenu(.copyPath, [.copyFullPath, .copyName, .copyFolderPath]),
                .action(.copyToShelf),
                .action(.openTerminal),
                .submenu(.newFile, [.newTextFile, .newMarkdownFile, .newEmptyFile]),
                .separator,
                .action(.compressZip),
                .action(.moveTo),
                .action(.copyTo),
            ]
            if !single { entries.append(.action(.batchRename)) }
            entries.append(.action(.deletePermanently))
            entries.append(.separator)
            if kinds.allSatisfy({ $0 == .image }) {
                entries.append(.submenu(.convertImage, [.convertJPEG, .convertPNG, .convertHEIC, .convertPDF]))
                entries.append(.action(.resizeImages))
                if single {
                    entries.append(.action(.extractText))
                    entries.append(.action(.copyImage))
                }
            }
            if single, kinds[0] == .video {
                entries.append(.action(.editVideo))
                entries.append(.submenu(.compressVideo,
                                        [.compressVideoSmall, .compressVideoEmail, .compressVideoCustom]))
                entries.append(.action(.makeGIF))
            }
            if single, kinds[0] == .application { entries.append(.action(.uninstallApp)) }
            if single, kinds[0] == .diskImage { entries.append(.action(.installDiskImage)) }
        }
        return tidied(entries, available: available)
    }

    private static func tidied(_ entries: [FinderMenuEntry],
                               available: Set<FinderAction>) -> [FinderMenuEntry] {
        var result: [FinderMenuEntry] = []
        for entry in entries {
            switch entry {
            case let .action(action):
                if available.contains(action) { result.append(entry) }
            case let .submenu(group, actions):
                let kept = actions.filter(available.contains)
                if !kept.isEmpty { result.append(.submenu(group, kept)) }
            case .separator:
                if let last = result.last, last != .separator { result.append(entry) }
            }
        }
        while result.last == .separator { result.removeLast() }
        return result
    }

    // MARK: Files

    /// Where "here" is: inside a single folder, otherwise next to the first item.
    static func workingDirectory(for urls: [URL], isDirectory: (URL) -> Bool) -> URL? {
        guard let first = urls.first else { return nil }
        if urls.count == 1, isDirectory(first) { return first }
        return first.deletingLastPathComponent()
    }

    /// The folder every item sits in, or nil when they come from several.
    static func sharedParent(of urls: [URL]) -> URL? {
        guard let parent = urls.first?.standardizedFileURL.deletingLastPathComponent() else { return nil }
        let path = parent.path
        return urls.allSatisfy { $0.standardizedFileURL.deletingLastPathComponent().path == path }
            ? parent : nil
    }

    /// `name`, or "name 2", "name 3"… before the extension, the way Finder
    /// numbers a copy, skipping whatever `exists` reports as taken.
    static func uniqueURL(in directory: URL, name: String, exists: (URL) -> Bool) -> URL {
        let candidate = directory.appendingPathComponent(name)
        guard exists(candidate) else { return candidate }
        let ns = name as NSString
        let ext = ns.pathExtension
        let base = ext.isEmpty ? name : ns.deletingPathExtension
        var number = 2
        while true {
            let numbered = ext.isEmpty ? "\(base) \(number)" : "\(base) \(number).\(ext)"
            let url = directory.appendingPathComponent(numbered)
            if !exists(url) { return url }
            number += 1
        }
    }

    static func archiveName(for urls: [URL], fallback: String) -> String {
        guard urls.count == 1, let url = urls.first else { return "\(fallback).zip" }
        return "\(url.lastPathComponent).zip"
    }

    /// True when `destination` is `source` itself or lies inside it, where a
    /// move or copy would recurse into its own result.
    static func destination(_ destination: URL, isInside source: URL) -> Bool {
        let target = destination.standardizedFileURL.resolvingSymlinksInPath().path
        let origin = source.standardizedFileURL.resolvingSymlinksInPath().path
        return target == origin || target.hasPrefix(origin.hasSuffix("/") ? origin : origin + "/")
    }

    // MARK: Batch rename

    struct RenameRule: Equatable {
        var find = ""
        var replace = ""
        var prefix = ""
        var suffix = ""
        var numbers = false
        var startNumber = 1
    }

    enum RenameProblem: Equatable {
        case invalidName, duplicateName, nameTaken
    }

    /// Applies the rule to each name. The text is edited before the
    /// extension, which stays as it was, and numbers are padded to the width
    /// of the largest one so the files keep their order when sorted.
    static func renamedNames(for names: [String], rule: RenameRule) -> [String] {
        let start = max(0, rule.startNumber)
        let width = String(start + max(0, names.count - 1)).count
        return names.enumerated().map { offset, name in
            let ns = name as NSString
            let ext = ns.pathExtension
            var base = ext.isEmpty ? name : ns.deletingPathExtension
            if !rule.find.isEmpty {
                base = base.replacingOccurrences(of: rule.find, with: rule.replace)
            }
            base = rule.prefix + base + rule.suffix
            if rule.numbers {
                let number = String(start + offset)
                base += " " + String(repeating: "0", count: max(0, width - number.count)) + number
            }
            return ext.isEmpty ? base : "\(base).\(ext)"
        }
    }

    static func isInvalidFileName(_ name: String) -> Bool {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty || trimmed == "." || trimmed == ".."
            || name.contains("/") || name.contains(":") || name.contains("\0")
            || name.utf8.count > 255
    }

    /// Why the proposed names cannot be applied, if they cannot. Names are
    /// compared case-insensitively, as the default APFS volume does.
    /// `existingNames` is everything already in the folder.
    static func renameProblem(original: [String], proposed: [String],
                              existingNames: Set<String>) -> RenameProblem? {
        if proposed.contains(where: isInvalidFileName) { return .invalidName }
        let folded = proposed.map { $0.lowercased() }
        if Set(folded).count != folded.count { return .duplicateName }
        let freed = Set(original.map { $0.lowercased() })
        let taken = Set(existingNames.map { $0.lowercased() }).subtracting(freed)
        if folded.contains(where: taken.contains) { return .nameTaken }
        return nil
    }
}
