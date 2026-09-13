// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 PowerTools contributors

import SwiftUI

/// Renames several items at once from the Finder right-click menu, with a
/// live preview. Nothing is renamed until every new name is valid and free.
struct FinderBatchRenameView: View {
    let urls: [URL]
    let strings: FinderActionsStrings
    let onClose: () -> Void

    @State private var rule = FinderActionsSupport.RenameRule()
    @State private var failure: String?
    @State private var folderContents: [String: Set<String>] = [:]

    private var originals: [String] { urls.map(\.lastPathComponent) }

    var body: some View {
        let names = FinderActionsSupport.renamedNames(for: originals, rule: rule)
        let problem = self.problem(for: names)
        VStack(alignment: .leading, spacing: 0) {
            Form {
                TextField(strings.renameFind, text: $rule.find)
                TextField(strings.renameReplace, text: $rule.replace)
                TextField(strings.renamePrefix, text: $rule.prefix)
                TextField(strings.renameSuffix, text: $rule.suffix)
                Toggle(strings.renameNumbers, isOn: $rule.numbers)
                if rule.numbers {
                    Stepper(value: $rule.startNumber, in: 0...99_999) {
                        HStack {
                            Text(strings.renameStart)
                            Spacer()
                            Text("\(rule.startNumber)").monospacedDigit()
                        }
                    }
                }
            }
            .formStyle(.grouped)
            .fixedSize(horizontal: false, vertical: true)

            List(originals.indices, id: \.self) { index in
                HStack(spacing: 8) {
                    Text(originals[index])
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .foregroundStyle(.secondary)
                    Image(systemName: "arrow.right")
                        .foregroundStyle(.tertiary)
                    Text(names[index])
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }
            .frame(minHeight: 160)

            HStack(spacing: 10) {
                if let message = failure ?? problem.map(message(for:)) {
                    Text(message)
                        .font(.caption)
                        .foregroundStyle(.orange)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
                Button(strings.cancel, action: onClose)
                    .keyboardShortcut(.cancelAction)
                Button(strings.renameButton) { apply(names) }
                    .keyboardShortcut(.defaultAction)
                    .disabled(problem != nil || names == originals)
            }
            .padding(16)
        }
        .frame(minWidth: 460, minHeight: 480)
        .onAppear(perform: loadFolderContents)
        .onChange(of: rule) { _, _ in failure = nil }
    }

    /// Checked folder by folder: a new name only has to be free where its
    /// own item lives.
    private func problem(for names: [String]) -> FinderActionsSupport.RenameProblem? {
        let groups = Dictionary(grouping: urls.indices) { urls[$0].deletingLastPathComponent().path }
        var found: [FinderActionsSupport.RenameProblem] = []
        for (folder, indices) in groups {
            if let problem = FinderActionsSupport.renameProblem(original: indices.map { originals[$0] },
                                                                proposed: indices.map { names[$0] },
                                                                existingNames: folderContents[folder] ?? []) {
                found.append(problem)
            }
        }
        for problem in [FinderActionsSupport.RenameProblem.invalidName, .duplicateName, .nameTaken]
        where found.contains(problem) {
            return problem
        }
        return nil
    }

    private func message(for problem: FinderActionsSupport.RenameProblem) -> String {
        switch problem {
        case .invalidName: return strings.renameInvalid
        case .duplicateName: return strings.renameDuplicate
        case .nameTaken: return strings.renameTaken
        }
    }

    private func loadFolderContents() {
        var contents: [String: Set<String>] = [:]
        for folder in Set(urls.map { $0.deletingLastPathComponent().path }) {
            contents[folder] = Set((try? FileManager.default.contentsOfDirectory(atPath: folder)) ?? [])
        }
        folderContents = contents
    }

    private func apply(_ names: [String]) {
        do {
            try FinderActionsService.applyRenames(Array(zip(urls, names)))
            onClose()
        } catch {
            failure = String(format: strings.failedFormat, error.localizedDescription)
            loadFolderContents()
        }
    }
}
