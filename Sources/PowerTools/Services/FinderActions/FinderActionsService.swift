// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 PowerTools contributors

import AppKit
import AVFoundation
import Combine
import FinderSync
import ImageIO
import SwiftUI

/// Carries out what the Finder right-click menu asks for. The extension only
/// names an action and the selected paths (see FinderActionsSupport); every
/// file operation, window and confirmation happens here, in the app, where
/// the installed features and the user's own Media settings live.
final class FinderActionsService {
    static let shared = FinderActionsService()

    private static let extensionName = "PowerToolsFinderMenu"

    /// Serial: publishing the menu and taking request files never overlap.
    private let requestQueue = DispatchQueue(label: "com.powertools.utils.finder-actions.requests",
                                             qos: .userInitiated)
    /// Long file work (zip, copy, delete) runs here so the menu bar stays live.
    private let workQueue = DispatchQueue(label: "com.powertools.utils.finder-actions.work",
                                          qos: .userInitiated, attributes: .concurrent)
    private var observations = Set<AnyCancellable>()
    private var mediaObservation: AnyCancellable?
    private var renameWindow: NSWindow?
    private var renameWindowObserver: NSObjectProtocol?
    private var extensionRegistered = false
    /// Remembered for the next Move to / Copy to panel, for this session only.
    private var lastDestination: URL?

    private init() {}

    private var strings: FinderActionsStrings { FeatureStrings.finderActions(L10n.shared.language) }
    private var hostBundleIdentifier: String { Bundle.main.bundleIdentifier ?? "" }
    private var home: URL { FileManager.default.homeDirectoryForCurrentUser }

    var isEnabled: Bool {
        AppFeature.finderActions.isAvailable
            && UserDefaults.standard.bool(forKey: DefaultsKey.finderActionsEnabled)
    }

    static var isExtensionEnabled: Bool { FIFinderSyncController.isExtensionEnabled }

    static func showExtensionSettings() {
        FIFinderSyncController.showExtensionManagementInterface()
    }

    private static var urlScheme: String? {
        let types = Bundle.main.object(forInfoDictionaryKey: "CFBundleURLTypes") as? [[String: Any]] ?? []
        return types.first { ($0["CFBundleURLName"] as? String)?.hasSuffix(".finder-menu") == true }
            .flatMap { ($0["CFBundleURLSchemes"] as? [String])?.first }
    }

    // MARK: - Preferences

    func syncWithPreferences() {
        precondition(Thread.isMainThread)
        if observations.isEmpty {
            L10n.shared.$language
                .dropFirst()
                .receive(on: DispatchQueue.main)
                .sink { [weak self] _ in self?.publishConfiguration() }
                .store(in: &observations)
            // Installing or removing Shelf, Media and the rest changes which
            // actions the menu can offer.
            FeatureRuntime.shared.$revision
                .dropFirst()
                .receive(on: DispatchQueue.main)
                .sink { [weak self] _ in self?.publishConfiguration() }
                .store(in: &observations)
        }
        publishConfiguration()
        if isEnabled { registerExtension() }
    }

    /// Called when the user turns the menu on: the same switch as the
    /// extension's checkbox in System Settings, flipped on their behalf. It is
    /// not repeated at launch, so turning the extension off there sticks.
    func enableExtension() {
        let identifier = "\(hostBundleIdentifier).finder-menu"
        registerExtension()
        workQueue.async {
            _ = BoundedProcessRunner.run("/usr/bin/pluginkit", ["-e", "use", "-i", identifier],
                                         timeout: 15, maxOutputBytes: 16_384)
        }
    }

    /// Makes sure this copy of the app is the one the system loads the
    /// extension from, which matters after a move or an update.
    private func registerExtension() {
        guard !extensionRegistered,
              let appex = Bundle.main.builtInPlugInsURL?
                .appendingPathComponent("\(Self.extensionName).appex", isDirectory: true),
              FileManager.default.fileExists(atPath: appex.path) else { return }
        extensionRegistered = true
        workQueue.async {
            _ = BoundedProcessRunner.run("/usr/bin/pluginkit", ["-a", appex.path],
                                         timeout: 15, maxOutputBytes: 16_384)
        }
    }

    private func publishConfiguration() {
        guard !hostBundleIdentifier.isEmpty else { return }
        let s = strings
        let configuration = FinderMenuConfiguration(
            version: FinderMenuConfiguration.currentVersion,
            rootTitle: s.menuRoot,
            actionTitles: Dictionary(uniqueKeysWithValues: FinderAction.allCases.map {
                ($0.rawValue, Self.title(for: $0, s))
            }),
            groupTitles: Dictionary(uniqueKeysWithValues: FinderMenuGroup.allCases.map {
                ($0.rawValue, Self.title(for: $0, s))
            }),
            availableActions: isEnabled ? FinderAction.allCases.filter(canRun) : [])
        let directory = FinderActionsSupport.menuDirectory(home: home, hostBundleIdentifier: hostBundleIdentifier)
        let requests = FinderActionsSupport.requestsDirectory(home: home, hostBundleIdentifier: hostBundleIdentifier)
        let destination = FinderActionsSupport.configurationURL(home: home, hostBundleIdentifier: hostBundleIdentifier)
        requestQueue.async {
            let fm = FileManager.default
            do {
                try fm.createDirectory(at: requests, withIntermediateDirectories: true,
                                       attributes: [.posixPermissions: 0o700])
                try? fm.setAttributes([.posixPermissions: 0o700], ofItemAtPath: directory.path)
                let encoder = JSONEncoder()
                encoder.outputFormatting = [.sortedKeys]
                try encoder.encode(configuration).write(to: destination, options: .atomic)
            } catch {
                NSLog("PowerTools could not publish the Finder menu: %@", error.localizedDescription)
            }
            Self.discardStaleRequests(in: requests)
        }
    }

    private static func discardStaleRequests(in directory: URL) {
        let fm = FileManager.default
        guard let entries = try? fm.contentsOfDirectory(at: directory,
                                                        includingPropertiesForKeys: [.contentModificationDateKey])
        else { return }
        let cutoff = Date().addingTimeInterval(-FinderActionsSupport.maximumRequestAge)
        for entry in entries {
            let modified = (try? entry.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate
            if (modified ?? .distantPast) < cutoff { try? fm.removeItem(at: entry) }
        }
    }

    private func canRun(_ action: FinderAction) -> Bool {
        switch action {
        case .copyToShelf:
            return AppFeature.shelf.isAvailable && UserDefaults.standard.bool(forKey: DefaultsKey.shelfEnabled)
        case .convertJPEG, .convertPNG, .convertHEIC, .convertPDF, .resizeImages, .extractText,
             .compressVideoSmall, .compressVideoEmail, .compressVideoCustom, .makeGIF:
            return AppFeature.mediaTools.isAvailable
        case .editVideo:
            return AppFeature.mediaTools.isAvailable || AppFeature.screenRecorder.isAvailable
        case .uninstallApp:
            return AppFeature.uninstaller.isAvailable
        case .installDiskImage:
            return AppFeature.diskImageInstaller.isAvailable
        case .copyFullPath, .copyName, .copyFolderPath, .openTerminal, .newTextFile, .newMarkdownFile,
             .newEmptyFile, .compressZip, .moveTo, .copyTo, .batchRename, .deletePermanently, .copyImage:
            return true
        }
    }

    private static func title(for action: FinderAction, _ s: FinderActionsStrings) -> String {
        switch action {
        case .copyFullPath: return s.copyFullPath
        case .copyName: return s.copyName
        case .copyFolderPath: return s.copyFolderPath
        case .copyToShelf: return s.copyToShelf
        case .openTerminal: return s.openTerminal
        case .newTextFile: return s.newTextFile
        case .newMarkdownFile: return s.newMarkdownFile
        case .newEmptyFile: return s.newEmptyFile
        case .compressZip: return s.compressZip
        case .moveTo: return s.moveTo
        case .copyTo: return s.copyTo
        case .batchRename: return s.batchRename
        case .deletePermanently: return s.deletePermanently
        // Format names read the same in every language.
        case .convertJPEG: return "JPEG"
        case .convertPNG: return "PNG"
        case .convertHEIC: return "HEIC"
        case .convertPDF: return "PDF"
        case .resizeImages: return s.resizeImages
        case .extractText: return s.extractText
        case .copyImage: return s.copyImage
        case .editVideo: return s.editVideo
        case .compressVideoSmall: return s.compressVideoSmall
        case .compressVideoEmail: return s.compressVideoEmail
        case .compressVideoCustom: return s.compressVideoCustom
        case .makeGIF: return s.makeGIF
        case .uninstallApp: return s.uninstallApp
        case .installDiskImage: return s.installDiskImage
        }
    }

    private static func title(for group: FinderMenuGroup, _ s: FinderActionsStrings) -> String {
        switch group {
        case .copyPath: return s.groupCopyPath
        case .newFile: return s.groupNewFile
        case .convertImage: return s.groupConvertImage
        case .compressVideo: return s.groupCompressVideo
        }
    }

    // MARK: - Requests

    /// Takes a URL opened on the app. Returns false for URLs that are not the
    /// Finder menu's; a matching URL still does nothing unless its request
    /// file is there, fresh, and names an action the app can run right now.
    @discardableResult
    func handle(_ url: URL) -> Bool {
        guard let scheme = Self.urlScheme,
              let id = FinderActionsSupport.requestID(from: url, scheme: scheme),
              !hostBundleIdentifier.isEmpty else { return false }
        let requests = FinderActionsSupport.requestsDirectory(home: home, hostBundleIdentifier: hostBundleIdentifier)
        let fileURL = FinderActionsSupport.requestFileURL(in: requests, id: id)
        requestQueue.async { [weak self] in
            let data = Self.takeRequestFile(at: fileURL)
            DispatchQueue.main.async {
                guard let self, let data,
                      let request = FinderActionsSupport.validatedRequest(data, expectedID: id, now: Date()),
                      self.isEnabled, self.canRun(request.action) else { return }
                self.perform(request)
            }
        }
        return true
    }

    /// Reads and removes a request, refusing anything but a small regular file
    /// owned by this user: the folder is private, but a link planted in it
    /// must not steer the read somewhere else.
    private static func takeRequestFile(at url: URL) -> Data? {
        let fm = FileManager.default
        guard let attributes = try? fm.attributesOfItem(atPath: url.path) else { return nil }
        defer { try? fm.removeItem(at: url) }
        guard attributes[.type] as? FileAttributeType == .typeRegular,
              (attributes[.ownerAccountID] as? NSNumber)?.uint32Value == getuid(),
              let size = (attributes[.size] as? NSNumber)?.intValue,
              size <= FinderActionsSupport.maximumRequestBytes else { return nil }
        return try? Data(contentsOf: url)
    }

    private func perform(_ request: FinderActionRequest) {
        let fm = FileManager.default
        let urls = request.paths.map { URL(fileURLWithPath: $0) }.filter { fm.fileExists(atPath: $0.path) }
        guard let first = urls.first else { return }
        switch request.action {
        case .copyFullPath: copy(lines: urls.map(\.path))
        case .copyName: copy(lines: urls.map(\.lastPathComponent))
        case .copyFolderPath:
            var seen = Set<String>()
            copy(lines: urls.map { $0.deletingLastPathComponent().path }.filter { seen.insert($0).inserted })
        case .copyToShelf:
            if !ShelfService.shared.add(fileURLs: urls) {
                showFailure(FeatureStrings.finderActions(L10n.shared.language).copyToShelf)
            }
        case .openTerminal: openTerminal(urls)
        case .newTextFile: createFile(near: urls, fileExtension: "txt")
        case .newMarkdownFile: createFile(near: urls, fileExtension: "md")
        case .newEmptyFile: createFile(near: urls, fileExtension: "")
        case .compressZip: compress(urls)
        case .moveTo: transfer(urls, moving: true)
        case .copyTo: transfer(urls, moving: false)
        case .batchRename: showBatchRename(urls)
        case .deletePermanently: deletePermanently(urls)
        case .convertJPEG: processImages(urls, options: conversionOptions(.jpeg))
        case .convertPNG: processImages(urls, options: conversionOptions(.png))
        case .convertHEIC: processImages(urls, options: conversionOptions(.heic))
        case .convertPDF: processImages(urls, options: conversionOptions(.pdf))
        case .resizeImages: processImages(urls, options: savedImageOptions())
        case .extractText: extractText(first)
        case .copyImage: copyImage(first)
        case .editVideo: editVideo(first)
        case .compressVideoSmall: compressVideo(first, targetMegabytes: 8)
        case .compressVideoEmail: compressVideo(first, targetMegabytes: 20)
        case .compressVideoCustom: compressVideo(first, targetMegabytes: nil)
        case .makeGIF: makeGIF(first)
        case .uninstallApp:
            AppUninstaller.shared.select(appURL: first)
            SettingsRouter.shared.page = .uninstaller
            NSApp.activate(ignoringOtherApps: true)
            appDelegate()?.openSettingsWindow()
        case .installDiskImage:
            // Mounting is all it takes: the disk image installer watches for
            // new volumes and offers the app inside.
            NSWorkspace.shared.open(first)
        }
    }

    // MARK: - Feedback

    private func show(_ message: String, icon: String = "checkmark.circle") {
        QuickToolHUD.show(icon: icon, message: message)
    }

    private func showFailure(_ reason: String) {
        show(String(format: strings.failedFormat, reason), icon: "exclamationmark.triangle")
    }

    /// Selects results in Finder. Items on the desktop are already in view,
    /// and selecting them would open a window of the Desktop folder instead.
    private func reveal(_ urls: [URL]) {
        guard !urls.isEmpty else { return }
        let desktop = FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask)
            .first?.standardizedFileURL.path
        guard !urls.allSatisfy({ $0.deletingLastPathComponent().standardizedFileURL.path == desktop })
        else { return }
        NSWorkspace.shared.activateFileViewerSelecting(urls)
    }

    private func finishSaving(_ outputs: [URL]) {
        guard let first = outputs.first else { return }
        let name = outputs.count == 1
            ? first.lastPathComponent
            : first.deletingLastPathComponent().lastPathComponent
        show(String(format: strings.savedFormat, name))
        reveal(outputs)
    }

    private static func isFolder(_ url: URL) -> Bool {
        let values = try? url.resourceValues(forKeys: [.isDirectoryKey, .isPackageKey])
        return values?.isDirectory == true && values?.isPackage != true
    }

    // MARK: - Everyday actions

    private func copy(lines: [String]) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(lines.joined(separator: "\n"), forType: .string)
        show(strings.copied, icon: "doc.on.doc")
    }

    private func openTerminal(_ urls: [URL]) {
        guard let directory = FinderActionsSupport.workingDirectory(for: urls, isDirectory: Self.isFolder),
              let terminal = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.Terminal")
        else { return }
        // Terminal opens a folder it is handed as a new window already in it.
        NSWorkspace.shared.open([directory], withApplicationAt: terminal,
                                configuration: NSWorkspace.OpenConfiguration()) { [weak self] _, error in
            guard let error else { return }
            DispatchQueue.main.async { self?.showFailure(error.localizedDescription) }
        }
    }

    private func createFile(near urls: [URL], fileExtension: String) {
        guard let directory = FinderActionsSupport.workingDirectory(for: urls, isDirectory: Self.isFolder)
        else { return }
        let fm = FileManager.default
        let name = fileExtension.isEmpty ? strings.untitled : "\(strings.untitled).\(fileExtension)"
        let target = FinderActionsSupport.uniqueURL(in: directory, name: name) { fm.fileExists(atPath: $0.path) }
        guard fm.createFile(atPath: target.path, contents: Data()) else {
            showFailure(target.lastPathComponent)
            return
        }
        show(String(format: strings.savedFormat, target.lastPathComponent), icon: "doc.badge.plus")
        // Selected, so Return renames it straight away.
        reveal([target])
    }

    private func compress(_ urls: [URL]) {
        guard let parent = FinderActionsSupport.sharedParent(of: urls) else {
            show(strings.mixedFolders, icon: "exclamationmark.triangle")
            return
        }
        let fm = FileManager.default
        let archive = FinderActionsSupport.uniqueURL(
            in: parent, name: FinderActionsSupport.archiveName(for: urls, fallback: strings.archive)
        ) { fm.fileExists(atPath: $0.path) }
        show(strings.working, icon: "archivebox")
        workQueue.async { [weak self] in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/zip")
            process.currentDirectoryURL = parent
            // Names go in as "./name" so one starting with a dash is never
            // read as an option; zip stores them without the prefix. Links
            // stay links, and Finder's own clutter stays out of the archive.
            process.arguments = ["-r", "-y", "-X", "-q", archive.path]
                + urls.map { "./" + $0.lastPathComponent }
                + ["-x", "*.DS_Store", "*__MACOSX*"]
            process.standardOutput = FileHandle.nullDevice
            process.standardError = FileHandle.nullDevice
            var succeeded = false
            do {
                try process.run()
                process.waitUntilExit()
                succeeded = process.terminationStatus == 0
            } catch {}
            if !succeeded { try? fm.removeItem(at: archive) }
            DispatchQueue.main.async {
                guard let self else { return }
                succeeded ? self.finishSaving([archive]) : self.showFailure(archive.lastPathComponent)
            }
        }
    }

    private func transfer(_ urls: [URL], moving: Bool) {
        let s = strings
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = moving ? s.moveButton : s.copyButton
        panel.message = moving ? s.moveMessage : s.copyMessage
        panel.directoryURL = lastDestination ?? urls.first?.deletingLastPathComponent()
        NSApp.activate(ignoringOtherApps: true)
        guard panel.runModal() == .OK, let destination = panel.url else { return }
        lastDestination = destination
        workQueue.async { [weak self] in
            let fm = FileManager.default
            let destinationPath = destination.standardizedFileURL.path
            var results: [URL] = []
            var failure: String?
            for url in urls {
                if FinderActionsSupport.destination(destination, isInside: url) {
                    failure = url.lastPathComponent
                    continue
                }
                if moving, url.deletingLastPathComponent().standardizedFileURL.path == destinationPath {
                    results.append(url)
                    continue
                }
                let target = FinderActionsSupport.uniqueURL(in: destination, name: url.lastPathComponent) {
                    fm.fileExists(atPath: $0.path)
                }
                do {
                    if moving {
                        try fm.moveItem(at: url, to: target)
                    } else {
                        try fm.copyItem(at: url, to: target)
                    }
                    results.append(target)
                } catch {
                    failure = error.localizedDescription
                }
            }
            DispatchQueue.main.async {
                self?.reveal(results)
                if let failure { self?.showFailure(failure) }
            }
        }
    }

    private func deletePermanently(_ urls: [URL]) {
        let s = strings
        let alert = NSAlert()
        alert.alertStyle = .critical
        alert.messageText = s.deleteTitle
        let names = urls.prefix(3).map(\.lastPathComponent).joined(separator: ", ")
            + (urls.count > 3 ? ", …" : "")
        alert.informativeText = String(format: s.deleteBodyFormat, names)
        alert.addButton(withTitle: s.deleteButton).hasDestructiveAction = true
        alert.addButton(withTitle: s.cancel)
        NSApp.activate(ignoringOtherApps: true)
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        workQueue.async { [weak self] in
            var failure: String?
            for url in urls {
                do {
                    try FileManager.default.removeItem(at: url)
                } catch {
                    failure = error.localizedDescription
                }
            }
            guard let failure else { return }
            DispatchQueue.main.async { self?.showFailure(failure) }
        }
    }

    // MARK: - Batch rename

    private func showBatchRename(_ urls: [URL]) {
        renameWindow?.close()
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 540, height: 560),
                              styleMask: [.titled, .closable, .resizable],
                              backing: .buffered, defer: false)
        window.title = strings.renameTitle
        window.isReleasedWhenClosed = false
        window.contentView = NSHostingView(rootView: FinderBatchRenameView(urls: urls, strings: strings) {
            [weak window] in window?.close()
        })
        window.center()
        WindowActivationPolicy.retain()
        // Delivered on the closing thread (always main), so a replaced window
        // has let go before the next one is stored.
        renameWindowObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification, object: window, queue: nil
        ) { [weak self] _ in
            guard let self else { return }
            if let observer = self.renameWindowObserver {
                NotificationCenter.default.removeObserver(observer)
            }
            self.renameWindowObserver = nil
            self.renameWindow = nil
            WindowActivationPolicy.release()
        }
        renameWindow = window
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }

    /// Renames in two passes through temporary names, so swapping two names,
    /// or changing only the letter case on a case-insensitive volume, works.
    /// On a failure, items still under a temporary name go back to their
    /// original one.
    static func applyRenames(_ pairs: [(URL, String)]) throws {
        let fm = FileManager.default
        var staged: [(temporary: URL, original: URL, final: URL)] = []
        do {
            for (url, name) in pairs where url.lastPathComponent != name {
                let folder = url.deletingLastPathComponent()
                let temporary = folder.appendingPathComponent(".powertools-rename-\(UUID().uuidString)")
                try fm.moveItem(at: url, to: temporary)
                staged.append((temporary, url, folder.appendingPathComponent(name)))
            }
            for entry in staged {
                try fm.moveItem(at: entry.temporary, to: entry.final)
            }
        } catch {
            for entry in staged where fm.fileExists(atPath: entry.temporary.path) {
                try? fm.moveItem(at: entry.temporary, to: entry.original)
            }
            throw error
        }
    }

    // MARK: - Media

    /// Runs one Media job and reports how it ended. Media does one thing at a
    /// time and a new job would cancel whatever the Media window is doing, so
    /// a busy service is left alone.
    private func runMedia(_ start: () -> Void, completion: @escaping (MediaResult) -> Void) {
        let media = MediaService.shared
        if case .running = media.state {
            show(strings.busy, icon: "hourglass")
            return
        }
        var started = false
        mediaObservation = media.$state
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                guard let self else { return }
                switch state {
                case .running:
                    started = true
                case let .completed(result) where started:
                    self.mediaObservation = nil
                    completion(result)
                case let .failed(failure) where started:
                    self.mediaObservation = nil
                    if failure != .cancelled { self.showFailure(Self.message(for: failure)) }
                case .cancelled where started:
                    self.mediaObservation = nil
                default:
                    break
                }
            }
        show(strings.working, icon: "gearshape")
        start()
    }

    private static func message(for failure: MediaFailure) -> String {
        let language = L10n.shared.language
        let s = L10n.shared.s
        switch failure {
        case .noInput: return s.mediaErrorNoFile
        case .noVideoTrack: return s.mediaErrorNoVideo
        case .sameOutput: return s.mediaErrorSameOutput
        case .unsupported: return s.mediaErrorUnsupported
        case .imageTooLarge: return MediaImageConverterStrings.localized(language).tooLarge
        case let .gifTooLong(maxSeconds):
            return String(format: FeatureStrings.recorder(language).gifTooLongFormat, maxSeconds)
        case .targetTooSmall: return s.mediaErrorTargetTooSmall
        case .watermarkUnavailable: return MediaImageConverterStrings.localized(language).noLogo
        case .cancelled: return s.mediaCancelled
        case let .failed(message): return message.isEmpty ? s.mediaErrorUnsupported : message
        }
    }

    private func processImages(_ urls: [URL], options: MediaImageOptions) {
        guard let parent = FinderActionsSupport.sharedParent(of: urls) else {
            show(strings.mixedFolders, icon: "exclamationmark.triangle")
            return
        }
        runMedia({
            MediaService.shared.processImages(inputURLs: urls, outputDirectory: parent, options: options)
        }) { [weak self] result in
            guard let self else { return }
            if result.outputURLs.isEmpty, let failure = result.imageBatchItems.compactMap(\.failure).first {
                self.showFailure(Self.message(for: failure))
                return
            }
            self.finishSaving(result.outputURLs)
        }
    }

    /// A conversion changes the format and nothing else: full size, no
    /// watermark, the original's name, and a quality high enough that the
    /// copy is not visibly worse.
    private func conversionOptions(_ format: MediaImageFormat) -> MediaImageOptions {
        let d = UserDefaults.standard
        return MediaImageOptions(
            quality: 0.9,
            maxDimension: Self.int(d, DefaultsKey.mediaImageMaxDimension, 1600),
            format: format,
            stripMetadata: Self.bool(d, DefaultsKey.mediaImageStripMetadata, true),
            resizeMode: .none,
            background: MediaImageBackground.sanitized(
                Self.string(d, DefaultsKey.mediaImageBackground, MediaImageBackground.transparent.rawValue)))
    }

    /// The same options the Media window would use right now.
    private func savedImageOptions() -> MediaImageOptions {
        let d = UserDefaults.standard
        let maxDimension = Self.int(d, DefaultsKey.mediaImageMaxDimension, 1600)
        return MediaImageOptions(
            quality: Self.double(d, DefaultsKey.mediaImageQuality, 0.72),
            maxDimension: maxDimension,
            format: MediaImageFormat.sanitized(
                Self.string(d, DefaultsKey.mediaImageFormat, MediaImageFormat.jpeg.rawValue)),
            stripMetadata: Self.bool(d, DefaultsKey.mediaImageStripMetadata, true),
            resizeMode: MediaImageResizeMode(
                kind: MediaImageResizeKind.sanitized(
                    Self.string(d, DefaultsKey.mediaImageResizeKind, MediaImageResizeKind.maxDimension.rawValue)),
                maxDimension: maxDimension,
                width: Self.int(d, DefaultsKey.mediaImageResizeWidth, 1600),
                height: Self.int(d, DefaultsKey.mediaImageResizeHeight, 1200),
                exactMode: MediaImageExactResizeMode.sanitized(
                    Self.string(d, DefaultsKey.mediaImageExactResizeMode,
                                MediaImageExactResizeMode.stretch.rawValue))),
            watermark: MediaImageWatermark(
                kind: MediaImageWatermarkKind.sanitized(
                    Self.string(d, DefaultsKey.mediaImageWatermarkKind, MediaImageWatermarkKind.off.rawValue)),
                text: Self.string(d, DefaultsKey.mediaImageWatermarkText, ""),
                logoPath: Self.string(d, DefaultsKey.mediaImageWatermarkLogoPath, ""),
                position: MediaImageWatermarkPosition.sanitized(
                    Self.string(d, DefaultsKey.mediaImageWatermarkPosition,
                                MediaImageWatermarkPosition.bottomRight.rawValue)),
                opacity: Self.double(d, DefaultsKey.mediaImageWatermarkOpacity, 0.45),
                margin: Self.int(d, DefaultsKey.mediaImageWatermarkMargin, 32),
                scale: Self.double(d, DefaultsKey.mediaImageWatermarkScale, 0.18)),
            renamePattern: MediaImageRenamePattern(Self.string(d, DefaultsKey.mediaImageRenamePattern, "")),
            background: MediaImageBackground.sanitized(
                Self.string(d, DefaultsKey.mediaImageBackground, MediaImageBackground.transparent.rawValue)),
            preserveModificationDate: Self.bool(d, DefaultsKey.mediaImagePreserveModificationDate, false))
    }

    private func extractText(_ url: URL) {
        let options = MediaTextOptions(
            accurate: Self.bool(UserDefaults.standard, DefaultsKey.mediaTextAccurate, true),
            languageCorrection: true,
            recognitionLanguages: MediaSupport.recognitionLanguages(for: L10n.shared.language.rawValue))
        runMedia({
            MediaService.shared.extractText(inputURL: url, outputURL: nil, options: options)
        }) { [weak self] result in
            guard let self else { return }
            let text = (result.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty else {
                self.show(self.strings.noText, icon: "text.viewfinder")
                return
            }
            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()
            pasteboard.setString(text, forType: .string)
            self.show(self.strings.textCopied, icon: "text.viewfinder")
        }
    }

    private func copyImage(_ url: URL) {
        workQueue.async { [weak self] in
            let image = Self.decodedImage(at: url)
            DispatchQueue.main.async {
                guard let self else { return }
                guard let image,
                      ScreenshotEditorController.copyImage(
                        image, fileNamePrefix: url.deletingPathExtension().lastPathComponent)
                else {
                    self.showFailure(L10n.shared.s.mediaErrorUnsupported)
                    return
                }
                self.show(self.strings.copied, icon: "photo.on.rectangle")
            }
        }
    }

    /// Full size and turned the way the photo is meant to be seen.
    private static func decodedImage(at url: URL) -> CGImage? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let size = MediaSupport.imageDisplaySize(properties: properties),
              MediaSupport.imageRenderSizeIsSafe(size) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: Int(max(size.width, size.height).rounded(.up)),
            kCGImageSourceShouldCacheImmediately: true,
        ]
        return CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
    }

    private func editVideo(_ url: URL) {
        let owner: AppFeature = AppFeature.mediaTools.isAvailable ? .mediaTools : .screenRecorder
        show(strings.working, icon: "film")
        Task { @MainActor [weak self] in
            let asset = AVURLAsset(url: url)
            let hasVideo = ((try? await asset.loadTracks(withMediaType: .video)) ?? []).isEmpty == false
            guard hasVideo else {
                self?.showFailure(L10n.shared.s.mediaErrorNoVideo)
                return
            }
            let take = await Task.detached(priority: .userInitiated) {
                RecorderTakeStore.shared.importVideo(at: url)
            }.value
            guard let take else {
                self?.showFailure(L10n.shared.s.mediaErrorUnsupported)
                return
            }
            if !ScreenRecorderService.shared.openEditor(with: take, owner: owner) {
                RecorderTakeStore.shared.delete(take)
            }
        }
    }

    /// The whole clip, either aimed at a file size or with the resolution and
    /// quality last chosen in the Media window.
    private func compressVideo(_ url: URL, targetMegabytes: Int?) {
        let d = UserDefaults.standard
        let sizing = targetMegabytes == nil
            ? MediaSizingMode.sanitized(Self.string(d, DefaultsKey.mediaVideoSizing, MediaSizingMode.resolution.rawValue))
            : .targetSize
        let options = MediaVideoOptions(
            start: 0,
            end: 0,
            quality: Self.double(d, DefaultsKey.mediaVideoQuality, 0.68),
            maxDimension: Self.int(d, DefaultsKey.mediaVideoMaxDimension, 1280),
            fps: 30,
            keepAudio: true,
            codec: .h264,
            sizing: sizing,
            targetBytes: MediaSupport.targetBytes(
                megabytes: targetMegabytes ?? Self.int(d, DefaultsKey.mediaVideoTargetMegabytes, 20)))
        let output = MediaSupport.uniqueOutputURL(for: url, suffix: "-compressed", fileExtension: "mp4")
        runMedia({
            MediaService.shared.compressVideo(inputURL: url, outputURL: output, options: options)
        }) { [weak self] result in
            self?.finishSaving(result.outputURLs)
        }
    }

    private func makeGIF(_ url: URL) {
        let d = UserDefaults.standard
        let options = MediaGIFOptions(
            start: 0,
            end: 0,
            quality: 0.74,
            width: Self.int(d, DefaultsKey.mediaGIFWidth, 720),
            fps: Self.double(d, DefaultsKey.mediaGIFFPS, 12),
            loops: Self.bool(d, DefaultsKey.mediaGIFLoops, true),
            sizing: MediaSizingMode.sanitized(
                Self.string(d, DefaultsKey.mediaGIFSizing, MediaSizingMode.resolution.rawValue)),
            targetBytes: MediaSupport.targetBytes(megabytes: Self.int(d, DefaultsKey.mediaGIFTargetMegabytes, 10)))
        let output = MediaSupport.uniqueOutputURL(for: url, suffix: "", fileExtension: "gif")
        runMedia({
            MediaService.shared.makeGIF(inputURL: url, outputURL: output, options: options)
        }) { [weak self] result in
            self?.finishSaving(result.outputURLs)
        }
    }

    // The Media window stores its choices through @AppStorage, whose
    // fallbacks only exist in the view; these read the same keys with the same
    // fallbacks.
    private static func double(_ d: UserDefaults, _ key: String, _ fallback: Double) -> Double {
        d.object(forKey: key) == nil ? fallback : d.double(forKey: key)
    }

    private static func int(_ d: UserDefaults, _ key: String, _ fallback: Int) -> Int {
        d.object(forKey: key) == nil ? fallback : d.integer(forKey: key)
    }

    private static func bool(_ d: UserDefaults, _ key: String, _ fallback: Bool) -> Bool {
        d.object(forKey: key) == nil ? fallback : d.bool(forKey: key)
    }

    private static func string(_ d: UserDefaults, _ key: String, _ fallback: String) -> String {
        d.string(forKey: key) ?? fallback
    }
}
