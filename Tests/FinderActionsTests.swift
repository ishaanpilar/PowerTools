// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 PowerTools contributors

import Foundation

enum FinderActionsTests {
    static func run(_ suite: TestSuite) {
        handOffChecks(suite)
        menuChecks(suite)
        fileChecks(suite)
        renameChecks(suite)
        bundleContractChecks(suite)
    }

    private static func handOffChecks(_ suite: TestSuite) {
        let scheme = "powertools-finder"
        let id = UUID()
        let url = FinderActionsSupport.requestURL(scheme: scheme, id: id)
        suite.expect(url.flatMap { FinderActionsSupport.requestID(from: $0, scheme: scheme) } == id,
                     "a request URL names its request")
        suite.expect(FinderActionsSupport.requestID(
                        from: URL(string: "powertools-dev-finder://run?id=\(id.uuidString)")!,
                        scheme: scheme) == nil,
                     "the other build variant's scheme is not this app's")
        suite.expect(FinderActionsSupport.requestID(
                        from: URL(string: "\(scheme)://run?id=\(id.uuidString)&action=deletePermanently")!,
                        scheme: scheme) == nil,
                     "a URL carries nothing but the request id")
        suite.expect(FinderActionsSupport.requestID(
                        from: URL(string: "\(scheme)://delete?id=\(id.uuidString)")!,
                        scheme: scheme) == nil,
                     "only the run host is understood")

        let now = Date()
        func encoded(_ request: FinderActionRequest) -> Data {
            (try? JSONEncoder().encode(request)) ?? Data()
        }
        let request = FinderActionRequest(id: id, action: .copyFullPath, paths: ["/tmp/a"], createdAt: now)
        suite.expect(FinderActionsSupport.validatedRequest(encoded(request), expectedID: id, now: now) == request,
                     "a fresh request is accepted")
        suite.expect(FinderActionsSupport.validatedRequest(encoded(request), expectedID: UUID(), now: now) == nil,
                     "a request file must be the one the URL named")
        suite.expect(FinderActionsSupport.validatedRequest(
                        encoded(request), expectedID: id,
                        now: now.addingTimeInterval(FinderActionsSupport.maximumRequestAge + 1)) == nil,
                     "a leftover request is dropped")
        suite.expect(FinderActionsSupport.validatedRequest(
                        encoded(FinderActionRequest(id: id, action: .copyName, paths: ["relative"], createdAt: now)),
                        expectedID: id, now: now) == nil,
                     "only absolute paths are acted on")
        suite.expect(FinderActionsSupport.validatedRequest(
                        encoded(FinderActionRequest(id: id, action: .copyName, paths: [], createdAt: now)),
                        expectedID: id, now: now) == nil,
                     "a request without items is dropped")
        suite.expect(FinderActionsSupport.validatedRequest(Data("{}".utf8), expectedID: id, now: now) == nil,
                     "malformed request data is dropped")

        let configuration = FinderMenuConfiguration(version: FinderMenuConfiguration.currentVersion,
                                                    rootTitle: "PowerTools",
                                                    actionTitles: ["copyName": "Name", "copyFullPath": ""],
                                                    groupTitles: [:],
                                                    availableActions: [.copyName])
        let decoded = (try? JSONEncoder().encode(configuration))
            .flatMap { try? JSONDecoder().decode(FinderMenuConfiguration.self, from: $0) }
        suite.expect(decoded == configuration
                        && configuration.title(for: .copyName) == "Name"
                        && configuration.title(for: .copyFullPath) == nil
                        && configuration.title(for: .copyPath) == nil,
                     "the published menu survives the trip and treats missing titles as absent")
    }

    private static func actions(_ entries: [FinderMenuEntry]) -> [FinderAction] {
        entries.flatMap { entry -> [FinderAction] in
            switch entry {
            case let .action(action): return [action]
            case let .submenu(_, actions): return actions
            case .separator: return []
            }
        }
    }

    private static func menuChecks(_ suite: TestSuite) {
        func file(_ path: String) -> URL { URL(fileURLWithPath: path) }
        let folder = URL(fileURLWithPath: "/x/Folder", isDirectory: true)
        suite.expect(FinderActionsSupport.kind(of: file("/x/photo.JPG")) == .image
                        && FinderActionsSupport.kind(of: file("/x/clip.mov")) == .video
                        && FinderActionsSupport.kind(of: file("/x/clip.mp4")) == .video
                        && FinderActionsSupport.kind(of: URL(fileURLWithPath: "/Applications/X.app", isDirectory: true))
                            == .application
                        && FinderActionsSupport.kind(of: file("/x/Installer.dmg")) == .diskImage
                        && FinderActionsSupport.kind(of: folder) == .folder
                        && FinderActionsSupport.kind(of: file("/x/notes.txt")) == .other
                        && FinderActionsSupport.kind(of: file("/x/README")) == .other,
                     "items are sorted into the kinds the menu cares about")

        let all = Set(FinderAction.allCases)
        let background = FinderActionsSupport.menu(for: [folder], isContainer: true, available: all)
        suite.expect(Set(actions(background)) == [.copyFullPath, .copyName, .openTerminal,
                                                 .newTextFile, .newMarkdownFile, .newEmptyFile],
                     "a folder's background offers only what needs no selection")

        let oneImage = actions(FinderActionsSupport.menu(for: [file("/x/a.png")], isContainer: false, available: all))
        suite.expect(oneImage.contains(.extractText) && oneImage.contains(.convertPDF)
                        && oneImage.contains(.copyImage) && !oneImage.contains(.batchRename)
                        && !oneImage.contains(.editVideo),
                     "one image gets the image actions")
        let twoImages = actions(FinderActionsSupport.menu(for: [file("/x/a.png"), file("/x/b.jpg")],
                                                         isContainer: false, available: all))
        suite.expect(twoImages.contains(.batchRename) && twoImages.contains(.resizeImages)
                        && !twoImages.contains(.extractText) && !twoImages.contains(.copyImage),
                     "several images convert together but read and copy one at a time")
        let mixed = actions(FinderActionsSupport.menu(for: [file("/x/a.png"), file("/x/b.mov")],
                                                     isContainer: false, available: all))
        suite.expect(!mixed.contains(.resizeImages) && !mixed.contains(.editVideo) && mixed.contains(.compressZip),
                     "a mixed selection gets only the general actions")
        let video = actions(FinderActionsSupport.menu(for: [file("/x/clip.mov")], isContainer: false, available: all))
        suite.expect(video.contains(.editVideo) && video.contains(.compressVideoSmall) && video.contains(.makeGIF),
                     "a video gets the video actions")
        let app = actions(FinderActionsSupport.menu(
            for: [URL(fileURLWithPath: "/Applications/X.app", isDirectory: true)], isContainer: false, available: all))
        suite.expect(app.contains(.uninstallApp) && !app.contains(.installDiskImage),
                     "an app offers to be uninstalled")

        suite.expect(FinderActionsSupport.menu(for: [file("/x/a.png")], isContainer: false,
                                               available: [.copyFullPath, .convertPNG])
                        == [.submenu(.copyPath, [.copyFullPath]), .separator, .submenu(.convertImage, [.convertPNG])],
                     "unavailable actions leave no empty submenu or doubled separator")
        suite.expect(FinderActionsSupport.menu(for: [], isContainer: false, available: all).isEmpty
                        && FinderActionsSupport.menu(for: [file("/x/a.png")], isContainer: false, available: []).isEmpty,
                     "nothing to act on, or nothing available, means no menu")

        let selections: [[URL]] = [[file("/x/a.png")], [file("/x/a.txt"), file("/x/b.txt")], [file("/x/clip.mov")],
                                    [file("/x/Installer.dmg")], [folder]]
        let wellFormed = selections.allSatisfy { urls in
            let entries = FinderActionsSupport.menu(for: urls, isContainer: false, available: all)
            return entries.first != .separator && entries.last != .separator
                && !zip(entries, entries.dropFirst()).contains { $0 == .separator && $1 == .separator }
        }
        suite.expect(wellFormed, "every menu starts and ends with an item and never doubles a separator")
    }

    private static func fileChecks(_ suite: TestSuite) {
        let directory = URL(fileURLWithPath: "/x", isDirectory: true)
        let taken: Set<String> = ["/x/untitled.txt", "/x/untitled 2.txt", "/x/Archive"]
        let exists: (URL) -> Bool = { taken.contains($0.path) }
        suite.expect(FinderActionsSupport.uniqueURL(in: directory, name: "untitled.txt", exists: exists)
                        .lastPathComponent == "untitled 3.txt"
                        && FinderActionsSupport.uniqueURL(in: directory, name: "Archive", exists: exists)
                        .lastPathComponent == "Archive 2"
                        && FinderActionsSupport.uniqueURL(in: directory, name: "new.md", exists: exists)
                        .lastPathComponent == "new.md",
                     "new names are numbered before the extension, the way Finder numbers copies")

        suite.expect(FinderActionsSupport.sharedParent(of: [URL(fileURLWithPath: "/x/a"), URL(fileURLWithPath: "/x/b")])?
                        .path == "/x"
                        && FinderActionsSupport.sharedParent(of: [URL(fileURLWithPath: "/x/a"),
                                                                  URL(fileURLWithPath: "/y/b")]) == nil,
                     "items share a parent only when they sit in the same folder")
        suite.expect(FinderActionsSupport.archiveName(for: [URL(fileURLWithPath: "/x/Folder")], fallback: "Archive")
                        == "Folder.zip"
                        && FinderActionsSupport.archiveName(for: [URL(fileURLWithPath: "/x/a"),
                                                                  URL(fileURLWithPath: "/x/b")],
                                                            fallback: "Archive") == "Archive.zip",
                     "one item names its archive; several use the fallback")
        suite.expect(FinderActionsSupport.destination(URL(fileURLWithPath: "/x/a/b"), isInside: URL(fileURLWithPath: "/x/a"))
                        && FinderActionsSupport.destination(URL(fileURLWithPath: "/x/a"), isInside: URL(fileURLWithPath: "/x/a"))
                        && !FinderActionsSupport.destination(URL(fileURLWithPath: "/x/ab"),
                                                             isInside: URL(fileURLWithPath: "/x/a")),
                     "a folder cannot be moved or copied into itself, but a sibling with a longer name is fine")

        let folders: Set<String> = ["/x/Folder"]
        let isDirectory: (URL) -> Bool = { folders.contains($0.path) }
        suite.expect(FinderActionsSupport.workingDirectory(for: [URL(fileURLWithPath: "/x/Folder")],
                                                           isDirectory: isDirectory)?.path == "/x/Folder"
                        && FinderActionsSupport.workingDirectory(for: [URL(fileURLWithPath: "/x/file.txt")],
                                                                 isDirectory: isDirectory)?.path == "/x"
                        && FinderActionsSupport.workingDirectory(for: [URL(fileURLWithPath: "/x/Folder"),
                                                                       URL(fileURLWithPath: "/x/file.txt")],
                                                                 isDirectory: isDirectory)?.path == "/x",
                     "\"here\" is inside a single folder and next to anything else")
    }

    private static func renameChecks(_ suite: TestSuite) {
        var rule = FinderActionsSupport.RenameRule()
        rule.find = "IMG_"
        rule.replace = "Trip "
        rule.numbers = true
        rule.startNumber = 9
        suite.expect(FinderActionsSupport.renamedNames(for: ["IMG_1.jpg", "IMG_2.jpg", "notes"], rule: rule)
                        == ["Trip 1 09.jpg", "Trip 2 10.jpg", "notes 11"],
                     "rename edits before the extension and pads numbers so the order sorts")
        var affixes = FinderActionsSupport.RenameRule()
        affixes.prefix = "A-"
        affixes.suffix = "-z"
        suite.expect(FinderActionsSupport.renamedNames(for: ["file.tar.gz"], rule: affixes) == ["A-file.tar-z.gz"],
                     "text added before and after the name leaves the extension alone")

        suite.expect(FinderActionsSupport.renameProblem(original: ["a"], proposed: ["a/b"], existingNames: ["a"])
                        == .invalidName
                        && FinderActionsSupport.renameProblem(original: ["a"], proposed: [" "], existingNames: ["a"])
                        == .invalidName,
                     "names with a slash, or only spaces, are refused")
        suite.expect(FinderActionsSupport.renameProblem(original: ["a", "b"], proposed: ["x.txt", "X.txt"],
                                                        existingNames: ["a", "b"]) == .duplicateName,
                     "two items cannot land on names that differ only in case")
        suite.expect(FinderActionsSupport.renameProblem(original: ["a.txt"], proposed: ["b.txt"],
                                                        existingNames: ["a.txt", "B.txt"]) == .nameTaken,
                     "a name already used by another item in the folder is refused")
        suite.expect(FinderActionsSupport.renameProblem(original: ["a", "b"], proposed: ["b", "a"],
                                                        existingNames: ["a", "b"]) == nil
                        && FinderActionsSupport.renameProblem(original: ["a.txt"], proposed: ["A.txt"],
                                                              existingNames: ["a.txt"]) == nil,
                     "swapping names and changing only the case are allowed")
    }

    private static func bundleContractChecks(_ suite: TestSuite) {
        func plist(_ path: String) -> [String: Any]? {
            (try? Data(contentsOf: URL(fileURLWithPath: path))).flatMap {
                try? PropertyListSerialization.propertyList(from: $0, format: nil) as? [String: Any]
            }
        }
        let entitlements = plist("Resources/FinderExtension/FinderExtension.entitlements")
        let appInfo = plist("Resources/Info.plist")
        let extensionInfo = plist("Resources/FinderExtension/Info.plist")
        let hostID = appInfo?["CFBundleIdentifier"] as? String ?? ""

        suite.expect((entitlements?["com.apple.security.app-sandbox"] as? Bool) == true
                        && (entitlements?["com.apple.security.temporary-exception.files.home-relative-path.read-write"]
                            as? [String]) == [FinderActionsSupport.sandboxExceptionPath(hostBundleIdentifier: hostID)],
                     "the extension is sandboxed with exactly the shared folder open")
        suite.expect("/Users/u" + FinderActionsSupport.sandboxExceptionPath(hostBundleIdentifier: hostID)
                        == FinderActionsSupport.menuDirectory(home: URL(fileURLWithPath: "/Users/u"),
                                                              hostBundleIdentifier: hostID).path + "/",
                     "the sandbox exception is the folder both sides use")

        let build = (try? String(contentsOfFile: "build.sh", encoding: .utf8)) ?? ""
        suite.expect(build.contains("/Library/Application Support/$APP_BUNDLE_ID/FinderMenu/"),
                     "build.sh rewrites the exception for each variant's bundle id")

        let nsExtension = extensionInfo?["NSExtension"] as? [String: Any]
        let source = (try? String(contentsOfFile: "Sources/FinderExtension/FinderMenuExtension.swift",
                                  encoding: .utf8)) ?? ""
        suite.expect(nsExtension?["NSExtensionPointIdentifier"] as? String == "com.apple.FinderSync"
                        && nsExtension?["NSExtensionPrincipalClass"] as? String == "PowerToolsFinderMenuExtension"
                        && source.contains("@objc(PowerToolsFinderMenuExtension)"),
                     "the extension's principal class is the one Info.plist names")

        let appSchemes = (appInfo?["CFBundleURLTypes"] as? [[String: Any]])?
            .first { ($0["CFBundleURLName"] as? String)?.hasSuffix(".finder-menu") == true }?["CFBundleURLSchemes"]
            as? [String]
        suite.expect(extensionInfo?[FinderActionsSupport.infoHostBundleIdentifierKey] as? String == hostID
                        && appSchemes == [extensionInfo?[FinderActionsSupport.infoURLSchemeKey] as? String ?? "?"],
                     "the extension points at the app and the scheme the app registers")
    }
}
