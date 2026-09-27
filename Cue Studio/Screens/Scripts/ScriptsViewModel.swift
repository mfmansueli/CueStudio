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
        [.all] + Platform.allCases.map(ScriptFilter.platform) + library.folders.map(ScriptFilter.folder)
    }

    func summary(takeCount: Int) -> String {
        let count = library.scripts.count
        guard count > 0 else { return "" }
        return String(localized: "\(count) scripts · \(takeCount) takes")
    }

    // MARK: - Single script

    func delete(_ script: Script) {
        library.delete([script.id])
        toast.show(String(localized: "Script deleted"))
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
        let count = selection.count
        guard count > 0 else { return }
        library.delete(selection)
        isSelecting = false
        toast.show(String(localized: "\(count) deleted"))
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
