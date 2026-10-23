//
//  EditorPart.swift
//  Cue Studio
//

import Foundation

/// A part of the editor with its own state (Captions, …): it reads and changes the edit, plays and picks through its session
/// (`EditorSession`), which it holds, with the same words the editor uses, so a tool's code reads the same wherever it lives.
@MainActor
protocol EditorPart: AnyObject {
    var session: EditorSession { get }
}

extension EditorPart {
    /// The recipe being edited. It changes only through the document: as an undo step (`changeEdit`, `change`, `commit`), by
    /// Undo and Redo, or with what listening found (`updateFindings`).
    var edit: TakeEdit { session.document.edit }
    /// What undo keeps of the edit.
    var snapshot: EditSnapshot { session.document.snapshot }
    var player: EditPlayback { session.player }
    var jobs: EditorJobs { session.jobs }
    var toast: ToastService { session.toast }
    var isReady: Bool { session.isReady }
    /// The editor closed: what a job hands back after is dropped.
    var isClosed: Bool { session.jobs.isClosed }

    var selection: EditorSelection? {
        get { session.selection }
        set { session.selection = newValue }
    }

    var panel: EditorPanel? {
        get { session.panel }
        set { session.panel = newValue }
    }

    var panelTab: EditorPanelTab {
        get { session.panelTab }
        set { session.panelTab = newValue }
    }

    var toolMenu: EditorToolMenu? {
        get { session.toolMenu }
        set { session.toolMenu = newValue }
    }

    var sheet: EditorSheet? {
        get { session.sheet }
        set { session.sheet = newValue }
    }

    /// Media files copied in while the editor is open (`EditorSession.importedFiles`).
    var importedFiles: Set<String> {
        get { session.importedFiles }
        set { session.importedFiles = newValue }
    }

    var undoAction: ToastAction { session.undoAction }

    func sayUndoable(_ message: String) {
        session.sayUndoable(message)
    }

    func previewPart(_ range: ClosedRange<TimeInterval>, back: TimeInterval? = nil) {
        session.previewPart(range, back: back)
    }

    func noteFailure(_ error: any Error, _ operation: String) {
        session.noteFailure(error, operation)
    }

    // MARK: - Changing the edit (`EditDocument`)

    /// Texts, media, voice-overs, captions, the cover or the style changed as an undo step.
    func change(key: String? = nil, _ update: (inout EditSnapshot) -> Void) {
        session.document.change(key: key, update)
    }

    /// Anything the creator decides on the edit, changed as an undo step.
    func changeEdit(key: String? = nil, _ update: (inout TakeEdit) -> Void) {
        session.document.changeEdit(key: key, update)
    }

    /// A new timeline (and decisions about suggestions) as an undo step.
    func commit(_ timeline: EditTimeline, suggestions: [CleanUpSuggestion]? = nil, key: String? = nil) {
        session.document.commit(timeline, suggestions: suggestions, key: key)
    }

    /// What undo keeps, changed as an undo step.
    func commit(_ next: EditSnapshot, key: String? = nil) {
        session.document.commit(next, key: key)
    }

    /// What listening found, laid on without an undo step.
    func updateFindings(_ update: (inout TakeEdit) -> Void) {
        session.document.updateFindings(update)
    }

    /// A gesture or a sheet starts changing something: all of it is one undo step.
    func beginChange() {
        session.document.beginChange()
    }

    /// The gesture or sheet is over.
    func endChange() {
        session.document.endChange()
    }
}
