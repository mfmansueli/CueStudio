//
//  ScriptEditorUndo.swift
//  Cue Studio
//

import Foundation
import Observation

/// Undo and Redo for the script page's text, for the buttons on the cues bar: they take back (or put back) what the creator typed,
/// deleted, or dropped in from the bar, through the text view's own undo manager. The editor hands it the manager when the keyboard
/// comes up; `canUndo` and `canRedo` follow it live (its notifications, and the editor's own changes, which it reports).
@Observable
final class ScriptEditorUndo {
    private(set) var canUndo = false
    private(set) var canRedo = false

    @ObservationIgnored private weak var manager: UndoManager?
    @ObservationIgnored private var observers: [NSObjectProtocol] = []

    /// Notifications after which what can be undone may have changed.
    private static let changes: [Notification.Name] = [
        .NSUndoManagerDidCloseUndoGroup, .NSUndoManagerDidUndoChange, .NSUndoManagerDidRedoChange, .NSUndoManagerCheckpoint,
    ]

    init() {}

    isolated deinit {
        stopObserving()
    }

    /// Follows `manager` (the text view's, once it is on screen).
    func attach(_ manager: UndoManager?) {
        guard manager !== self.manager else {
            refresh()
            return
        }
        stopObserving()
        self.manager = manager
        if let manager {
            observers = Self.changes.map { name in
                NotificationCenter.default.addObserver(forName: name, object: manager, queue: .main) { [weak self] _ in
                    MainActor.assumeIsolated { self?.refresh() }
                }
            }
        }
        refresh()
    }

    /// The editor is gone: nothing to undo from the bar until another one attaches.
    func detach(from manager: UndoManager?) {
        guard manager === self.manager else { return }
        stopObserving()
        self.manager = nil
        refresh()
    }

    func refresh() {
        let undo = manager?.canUndo ?? false
        let redo = manager?.canRedo ?? false
        if undo != canUndo { canUndo = undo }
        if redo != canRedo { canRedo = redo }
    }

    func undo() {
        guard let manager, manager.canUndo else { return }
        manager.undo()
        refresh()
    }

    func redo() {
        guard let manager, manager.canRedo else { return }
        manager.redo()
        refresh()
    }

    private func stopObserving() {
        observers.forEach(NotificationCenter.default.removeObserver)
        observers = []
    }
}
