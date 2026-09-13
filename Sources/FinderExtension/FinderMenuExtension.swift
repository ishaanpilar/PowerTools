// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 PowerTools contributors

import AppKit
import FinderSync

/// The PowerTools submenu in Finder's right-click menu. It only draws the
/// menu and passes the chosen action to the app (see FinderActionsSupport):
/// the sandbox keeps it away from the files themselves, and the app is what
/// knows which features are installed and speaks the user's chosen language.
@objc(PowerToolsFinderMenuExtension)
final class FinderMenuExtension: FIFinderSync {
    private let hostBundleIdentifier: String
    private let scheme: String
    private let home: URL

    override init() {
        let info = Bundle.main.infoDictionary ?? [:]
        hostBundleIdentifier = info[FinderActionsSupport.infoHostBundleIdentifierKey] as? String ?? ""
        scheme = info[FinderActionsSupport.infoURLSchemeKey] as? String ?? ""
        home = Self.userHome()
        super.init()
        // The whole disk, so the menu is there wherever Finder shows files:
        // every window, the desktop and mounted volumes alike.
        FIFinderSyncController.default().directoryURLs = [URL(fileURLWithPath: "/", isDirectory: true)]
    }

    /// Inside the sandbox the home directory APIs answer with the container;
    /// the shared folder is relative to the real home.
    private static func userHome() -> URL {
        if let entry = getpwuid(getuid()), let directory = entry.pointee.pw_dir {
            return URL(fileURLWithPath: String(cString: directory), isDirectory: true)
        }
        return FileManager.default.homeDirectoryForCurrentUser
    }

    override func menu(for menuKind: FIMenuKind) -> NSMenu? {
        let isContainer: Bool
        switch menuKind {
        case .contextualMenuForItems: isContainer = false
        case .contextualMenuForContainer: isContainer = true
        default: return nil
        }
        guard let configuration = loadConfiguration() else { return nil }
        let entries = FinderActionsSupport.menu(for: targetURLs(isContainer: isContainer),
                                                isContainer: isContainer,
                                                available: Set(configuration.availableActions))
        guard !entries.isEmpty else { return nil }

        let submenu = NSMenu(title: configuration.rootTitle)
        for entry in entries {
            switch entry {
            case let .action(action):
                if let item = item(for: action, configuration: configuration, isContainer: isContainer) {
                    submenu.addItem(item)
                }
            case let .submenu(group, actions):
                let items = actions.compactMap {
                    item(for: $0, configuration: configuration, isContainer: isContainer)
                }
                guard !items.isEmpty, let title = configuration.title(for: group) else { continue }
                let parent = NSMenuItem(title: title, action: nil, keyEquivalent: "")
                let children = NSMenu(title: title)
                items.forEach(children.addItem)
                parent.submenu = children
                submenu.addItem(parent)
            case .separator:
                submenu.addItem(.separator())
            }
        }
        guard !submenu.items.isEmpty else { return nil }

        let menu = NSMenu(title: "")
        let root = NSMenuItem(title: configuration.rootTitle, action: nil, keyEquivalent: "")
        root.image = NSImage(systemSymbolName: "bolt.fill", accessibilityDescription: nil)
        root.submenu = submenu
        menu.addItem(root)
        return menu
    }

    /// Finder hands the action a copy of the item that keeps only its tag, so
    /// the tag carries both the action and which kind of menu it came from.
    @IBAction func runAction(_ sender: AnyObject?) {
        guard let tag = (sender as? NSMenuItem)?.tag, tag >= 0 else { return }
        let actions = FinderAction.allCases
        guard actions.indices.contains(tag / 2) else { return }
        let urls = targetURLs(isContainer: tag % 2 == 1)
        guard !urls.isEmpty else { return }
        send(FinderActionRequest(action: actions[tag / 2], paths: urls.map(\.path)))
    }

    private func item(for action: FinderAction, configuration: FinderMenuConfiguration,
                      isContainer: Bool) -> NSMenuItem? {
        guard let title = configuration.title(for: action),
              let index = FinderAction.allCases.firstIndex(of: action) else { return nil }
        let item = NSMenuItem(title: title, action: #selector(runAction(_:)), keyEquivalent: "")
        item.target = self
        item.tag = index * 2 + (isContainer ? 1 : 0)
        return item
    }

    private func targetURLs(isContainer: Bool) -> [URL] {
        let controller = FIFinderSyncController.default()
        if isContainer { return controller.targetedURL().map { [$0] } ?? [] }
        return controller.selectedItemURLs() ?? []
    }

    /// The app writes this whenever the feature, the installed features or the
    /// language change. No file (the app never ran) or an unknown version
    /// means no menu rather than a guess.
    private func loadConfiguration() -> FinderMenuConfiguration? {
        guard !hostBundleIdentifier.isEmpty else { return nil }
        let url = FinderActionsSupport.configurationURL(home: home, hostBundleIdentifier: hostBundleIdentifier)
        guard let data = try? Data(contentsOf: url),
              let configuration = try? JSONDecoder().decode(FinderMenuConfiguration.self, from: data),
              configuration.version == FinderMenuConfiguration.currentVersion,
              !configuration.rootTitle.isEmpty else { return nil }
        return configuration
    }

    private func send(_ request: FinderActionRequest) {
        guard !hostBundleIdentifier.isEmpty, !scheme.isEmpty,
              let url = FinderActionsSupport.requestURL(scheme: scheme, id: request.id) else { return }
        let directory = FinderActionsSupport.requestsDirectory(home: home,
                                                               hostBundleIdentifier: hostBundleIdentifier)
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true,
                                                    attributes: [.posixPermissions: 0o700])
            try JSONEncoder().encode(request)
                .write(to: FinderActionsSupport.requestFileURL(in: directory, id: request.id),
                       options: .atomic)
        } catch {
            NSLog("PowerTools Finder menu could not write its request: %@", error.localizedDescription)
            return
        }
        // Not brought forward: most actions finish without a window, and the
        // ones that need one (a folder picker, a confirmation) activate the
        // app themselves.
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = false
        NSWorkspace.shared.open(url, configuration: configuration, completionHandler: nil)
    }
}
