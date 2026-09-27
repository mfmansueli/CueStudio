//
//  ScriptLibraryService.swift
//  Cue Studio
//

import Foundation
import os

/// The creator's scripts and folders. The only owner of script data: screens read from it and
/// call its actions, and it persists after every change.
@MainActor
@Observable
final class ScriptLibraryService {
    /// Most recently edited first.
    private(set) var scripts: [Script] = []
    private(set) var folders: [String] = []
    private(set) var hasLoaded = false

    private let repository: ScriptRepository
    private let now: () -> Date
    private let logger = Logger(subsystem: "studio.cue", category: "ScriptLibrary")

    init(repository: ScriptRepository = LocalScriptRepository(), now: @escaping () -> Date = Date.init) {
        self.repository = repository
        self.now = now
    }

    // MARK: - Loading

    func load() {
        do {
            let snapshot = try repository.load()
            scripts = snapshot.scripts.sorted { $0.updatedAt > $1.updatedAt }
            folders = snapshot.folders
        } catch {
            logger.error("Could not load scripts: \(error.localizedDescription)")
        }
        hasLoaded = true
    }

    func script(id: UUID?) -> Script? {
        guard let id else { return nil }
        return scripts.first { $0.id == id }
    }

    // MARK: - Scripts

    @discardableResult
    func create(
        title: String, text: String, platform: Platform, type: ScriptType? = nil, folder: String? = nil,
        factCheck: Bool = false
    ) -> Script {
        let date = now()
        let script = Script(
            title: title, text: text, platform: platform, type: type,
            folder: folder, createdAt: date, updatedAt: date, factCheck: factCheck
        )
        scripts.insert(script, at: 0)
        persist()
        return script
    }

    /// Applies a change and moves the script to the top as the last edited.
    func update(_ id: UUID, _ change: (inout Script) -> Void) {
        guard let index = scripts.firstIndex(where: { $0.id == id }) else { return }
        var script = scripts[index]
        change(&script)
        script.id = id
        script.updatedAt = now()
        scripts.remove(at: index)
        scripts.insert(script, at: 0)
        persist()
    }

    /// "Checked" on the fact-check banner. Not an edit, so the order stays the same.
    func markFactChecked(_ id: UUID) {
        guard let index = scripts.firstIndex(where: { $0.id == id }), scripts[index].factCheck else { return }
        scripts[index].factCheck = false
        persist()
    }

    func delete(_ ids: Set<UUID>) {
        guard !ids.isEmpty else { return }
        scripts.removeAll { ids.contains($0.id) }
        persist()
    }

    /// Copies start over at version 1 and are placed on top.
    @discardableResult
    func duplicate(_ ids: Set<UUID>) -> [Script] {
        let date = now()
        let copies = scripts.filter { ids.contains($0.id) }.map { original in
            var copy = original
            copy.id = UUID()
            copy.title = String(localized: "\(original.displayTitle) (copy)")
            copy.version = 1
            copy.createdAt = date
            copy.updatedAt = date
            return copy
        }
        scripts.insert(contentsOf: copies, at: 0)
        persist()
        return copies
    }

    // MARK: - Folders

    /// Creates a folder and returns its name, or nil when the name is empty or taken.
    @discardableResult
    func createFolder(named name: String) -> String? {
        let cleaned = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty,
              !folders.contains(where: { $0.caseInsensitiveCompare(cleaned) == .orderedSame })
        else { return nil }
        folders.append(cleaned)
        persist()
        return cleaned
    }

    /// Moving does not count as an edit, so the order stays the same.
    func move(_ ids: Set<UUID>, toFolder folder: String?) {
        for index in scripts.indices where ids.contains(scripts[index].id) {
            scripts[index].folder = folder
        }
        persist()
    }

    func deleteFolder(_ name: String) {
        folders.removeAll { $0 == name }
        for index in scripts.indices where scripts[index].folder == name {
            scripts[index].folder = nil
        }
        persist()
    }

    // MARK: - Persistence

    private func persist() {
        do {
            try repository.save(ScriptLibrarySnapshot(scripts: scripts, folders: folders))
        } catch {
            logger.error("Could not save scripts: \(error.localizedDescription)")
        }
    }
}
