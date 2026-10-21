//
//  ScriptEditorUndoTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

/// Undo and Redo on the cues bar follow the editor's undo manager live, and act on it.
@MainActor
@Suite("ScriptEditorUndo")
struct ScriptEditorUndoTests {
    private final class Page {
        var text = ""
    }

    /// One edit as the text view makes it: a closed group with its undo.
    private func edit(_ page: Page, to text: String, in manager: UndoManager) {
        let old = page.text
        manager.beginUndoGrouping()
        manager.registerUndo(withTarget: page) { [weak manager] page in
            let undone = page.text
            page.text = old
            manager?.registerUndo(withTarget: page) { $0.text = undone }
        }
        manager.endUndoGrouping()
        page.text = text
    }

    private func makeManager() -> UndoManager {
        let manager = UndoManager()
        manager.groupsByEvent = false
        return manager
    }

    @Test func nothingToUndoUntilTheCreatorEdits() async {
        let manager = makeManager()
        let undo = ScriptEditorUndo()
        undo.attach(manager)
        #expect(!undo.canUndo && !undo.canRedo)
        edit(Page(), to: "Hello", in: manager)
        await Wait.until { undo.canUndo }
        #expect(!undo.canRedo)
    }

    @Test func undoTakesTheEditBackAndRedoPutsItBack() async {
        let manager = makeManager()
        let page = Page()
        let undo = ScriptEditorUndo()
        undo.attach(manager)
        edit(page, to: "Hello", in: manager)
        await Wait.until { undo.canUndo }
        undo.undo()
        #expect(page.text.isEmpty)
        #expect(!undo.canUndo && undo.canRedo)
        undo.redo()
        #expect(page.text == "Hello")
        #expect(undo.canUndo && !undo.canRedo)
    }

    /// Without an editor (or once it is gone) the buttons have nothing to do, and pressing them is harmless.
    @Test func withoutAnEditorThereIsNothingToUndo() async {
        let manager = makeManager()
        let undo = ScriptEditorUndo()
        undo.attach(manager)
        edit(Page(), to: "Hello", in: manager)
        await Wait.until { undo.canUndo }
        undo.detach(from: UndoManager())
        #expect(undo.canUndo, "another editor's manager leaving doesn't detach this one")
        undo.detach(from: manager)
        #expect(!undo.canUndo && !undo.canRedo)
        undo.undo()
        undo.redo()
    }
}
