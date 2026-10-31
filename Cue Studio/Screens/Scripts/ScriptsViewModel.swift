//
//  ScriptsViewModel.swift
//  Cue Studio
//

import Foundation

@MainActor
@Observable
final class ScriptsViewModel {
    var filter: ScriptFilter = .all
    /// The words in the search field at the top of the list (always there).
    var query = ""
    var isSelecting = false {
        didSet { if !isSelecting { selection.removeAll() } }
    }
    /// What is picked while selecting: scripts, and the Logbook's ideas shown at the end of the list.
    var selection = Set<UUID>()
    /// Script whose actions are shown after swiping "More".
    var actionsTarget: Script?
    /// Script being shared from the "More" actions.
    var shareTarget: Script?
    var isNamingFolder = false
    var newFolderName = ""
    /// Scripts to move into the folder being created, if any.
    private var idsToMoveIntoNewFolder: Set<UUID> = []

    private let library: ScriptLibraryService
    private let toast: ToastService
    private let logbook: LogbookService

    init(library: ScriptLibraryService, toast: ToastService, logbook: LogbookService) {
        self.library = library
        self.toast = toast
        self.logbook = logbook
    }

    // MARK: - Reading

    var visibleScripts: [Script] {
        ScriptFilter.apply(filter, query: query, to: library.scripts)
    }

    var filters: [ScriptFilter] {
        [.all] + ScriptFilter.platformFilters(for: library.scripts, chosen: filter) + library.folders.map(ScriptFilter.folder)
    }

    /// The visible scripts in READY TO RECORD, DRAFTS and RECORDED.
    func groups(takeCount: (UUID) -> Int) -> [ScriptGroup] {
        ScriptGroup.groups(of: visibleScripts, takeCount: takeCount)
    }

    /// Why the list is empty under the card, when it is: nothing matches the search, the platform or the folder.
    var emptyResult: EmptyResult? {
        guard visibleScripts.isEmpty else { return nil }
        if !query.trimmingCharacters(in: .whitespaces).isEmpty { return .search }
        switch filter {
        case .all: return nil
        case .platform(let platform): return .platform(platform)
        case .folder(let name): return .folder(name)
        }
    }

    enum EmptyResult: Equatable {
        case search
        case platform(Platform)
        case folder(String)
    }

    /// How many scripts a filter chip stands for ("TikTok 7").
    func count(for filter: ScriptFilter) -> Int {
        library.scripts.filter(filter.matches).count
    }

    // MARK: - Single script

    /// Deletes, with Undo for 4 s: nothing is lost by a slip.
    func delete(_ script: Script) {
        remove([script], message: String(localized: "Script deleted"))
    }

    private func remove(_ scripts: [Script], ideas: [LogbookEntry] = [], message: String) {
        library.delete(Set(scripts.map(\.id)))
        let removedIdeas = logbook.delete(Set(ideas.map(\.id)))
        toast.show(message, action: ToastAction(title: String(localized: "Undo")) { [library, logbook] in
            library.restore(scripts)
            logbook.restore(removedIdeas)
        })
    }

    /// An idea of the Logbook's, held away from the end of the list: with Undo for 4 s, as a script.
    func delete(_ idea: LogbookEntry) {
        remove([], ideas: [idea], message: String(localized: "Idea deleted"))
    }

    func duplicate(_ script: Script) {
        library.duplicate([script.id])
        toast.show(String(localized: "Duplicated"))
    }

    func move(_ ids: Set<UUID>, to folder: String?) {
        library.move(ids, toFolder: folder)
        if let folder {
            toast.show(String(localized: "Moved to “\(folder)”"))
        } else {
            toast.show(String(localized: "Removed from folder"))
        }
    }

    // MARK: - Selection

    func toggleSelecting() {
        isSelecting.toggle()
    }

    /// A tap on a row while selecting: picks the script, or lets it go.
    func toggleSelection(of id: UUID) {
        if selection.remove(id) == nil { selection.insert(id) }
    }

    /// Every script shown (the chip and the search say which) is picked.
    var selectsAllShown: Bool {
        let shown = visibleScripts
        return !shown.isEmpty && shown.allSatisfy { selection.contains($0.id) }
    }

    /// Select all beside Delete: picks every script shown, or lets them all go once they are.
    func toggleSelectAll() {
        if selectsAllShown { selection.removeAll() } else { selection.formUnion(visibleScripts.map(\.id)) }
    }

    /// The scripts among what is picked: folders and Duplicate are theirs (an idea has neither).
    var selectedScripts: Set<UUID> {
        Set(library.scripts.lazy.map(\.id).filter(selection.contains))
    }

    /// Deletes what is picked, scripts and ideas together, with one Undo for all of it.
    func deleteSelection() {
        let doomed = library.scripts.filter { selection.contains($0.id) }
        let ideas = logbook.waiting.filter { selection.contains($0.id) }
        guard !doomed.isEmpty || !ideas.isEmpty else { return }
        isSelecting = false
        remove(doomed, ideas: ideas, message: String(localized: "\(doomed.count + ideas.count) deleted"))
    }

    func duplicateSelection() {
        let scripts = selectedScripts
        guard !scripts.isEmpty else { return }
        library.duplicate(scripts)
        isSelecting = false
        toast.show(String(localized: "Duplicated"))
    }

    func moveSelection(to folder: String?) {
        let scripts = selectedScripts
        guard !scripts.isEmpty else { return }
        move(scripts, to: folder)
        isSelecting = false
    }

    // MARK: - Folders

    func startNewFolder(moving ids: Set<UUID> = []) {
        newFolderName = ""
        idsToMoveIntoNewFolder = ids
        isNamingFolder = true
    }

    func confirmNewFolder() {
        guard let name = library.createFolder(named: newFolderName) else {
            if !newFolderName.trimmingCharacters(in: .whitespaces).isEmpty {
                toast.show(String(localized: "That folder already exists"), kind: .problem)
            }
            return
        }
        if idsToMoveIntoNewFolder.isEmpty {
            filter = .folder(name)
            toast.show(String(localized: "Folder created"))
        } else {
            move(idsToMoveIntoNewFolder, to: name)
            isSelecting = false
        }
        idsToMoveIntoNewFolder = []
    }

    /// Deletes a folder, with Undo for 4 s: its scripts stay, in All.
    func deleteFolder(_ name: String) {
        guard let removed = library.deleteFolder(name) else { return }
        if filter == .folder(name) { filter = .all }
        toast.show(
            String(localized: "Folder deleted"),
            action: ToastAction(title: String(localized: "Undo")) { [library] in library.restoreFolder(removed) }
        )
    }
}
