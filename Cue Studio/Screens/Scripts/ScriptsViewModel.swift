//
//  ScriptsViewModel.swift
//  Cue Studio
//

import Foundation

@MainActor
@Observable
final class ScriptsViewModel {
    var filter: ScriptFilter = .all
    var query = ""
    /// The magnifier in the bar: the search field is showing.
    var isSearching = false {
        didSet { if !isSearching { query = "" } }
    }
    var isSelecting = false {
        didSet { if !isSelecting { selection.removeAll() } }
    }
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

    init(library: ScriptLibraryService, toast: ToastService) {
        self.library = library
        self.toast = toast
    }

    // MARK: - Reading

    var visibleScripts: [Script] {
        ScriptFilter.apply(filter, query: query, to: library.scripts)
    }

    var filters: [ScriptFilter] {
        [.all] + ScriptFilter.platformFilters(for: library.scripts) + library.folders.map(ScriptFilter.folder)
    }

    /// "8 SCRIPTS · 3 READY": what is in the library and how many can be recorded right now.
    func summaryValues(takeCount: (UUID) -> Int) -> [String] {
        let scripts = library.scripts
        guard !scripts.isEmpty else { return [] }
        let ready = scripts.filter { $0.state(takeCount: takeCount($0.id)) == .ready }.count
        return [String(localized: "\(scripts.count) scripts"), String(localized: "\(ready) ready")]
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

    private func remove(_ scripts: [Script], message: String) {
        library.delete(Set(scripts.map(\.id)))
        toast.show(message, action: ToastAction(title: String(localized: "Undo")) { [library] in library.restore(scripts) })
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

    func deleteSelection() {
        let doomed = library.scripts.filter { selection.contains($0.id) }
        guard !doomed.isEmpty else { return }
        isSelecting = false
        remove(doomed, message: String(localized: "\(doomed.count) deleted"))
    }

    func duplicateSelection() {
        guard !selection.isEmpty else { return }
        library.duplicate(selection)
        isSelecting = false
        toast.show(String(localized: "Duplicated"))
    }

    func moveSelection(to folder: String?) {
        guard !selection.isEmpty else { return }
        move(selection, to: folder)
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
                toast.show(String(localized: "That folder already exists"))
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
}
