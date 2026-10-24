//
//  CaptionsPartTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

/// Captions as a part of the editor (`CaptionsViewModel`), with only a host around it: its changes are undo steps of the
/// session's document, it picks through the host, it keeps its own state for the panel and the edit it is told about, and it
/// stays safe once the editor has gone.
@MainActor
@Suite("Captions part")
struct CaptionsPartTests {
    let host: FakeEditorHost
    let part: CaptionsViewModel

    init() {
        var edit = TakeEdit(sourceDuration: 20, aspect: .portrait)
        edit.captions = [
            CaptionCue(text: "First line", start: 1, end: 3),
            CaptionCue(text: "Second line", start: 4, end: 6),
        ]
        edit.showsCaptions = true
        host = FakeEditorHost(edit: edit)
        part = Self.makePart(host.session)
    }

    private static func makePart(_ session: EditorSession) -> CaptionsViewModel {
        CaptionsViewModel(
            session: session, editing: FakeTakeEditor(),
            takes: TakeLibraryService(repository: FakeTakeRepository(takes: [])),
            library: ScriptLibraryService(repository: FakeScriptRepository(scripts: [])),
            styles: FakeTextStyleStore(), translations: FakeTranslationAvailability(),
            speechLanguage: { _ in .language(.english) }, likelySpokenLanguages: { _ in [] }, languageConflict: { _ in nil }
        )
    }

    @Test func aCorrectedLineIsAnUndoStepOfTheSession() {
        let id = host.document.edit.captions[0].id
        part.setCaptionText(id, "Fixed line")
        #expect(host.document.edit.captions[0].text == "Fixed line")
        #expect(host.document.canUndo)
        part.undoAction.perform()
        #expect(host.document.edit.captions[0].text == "First line")
    }

    @Test func aTappedLineIsPickedThroughTheHost() {
        let id = host.document.edit.captions[1].id
        part.pickCaptionLine(id, at: 4)
        #expect(host.selection == .caption(id))
        #expect(host.session.player.currentTime > 4)
    }

    @Test func picksBelongToTheListOfLines() {
        part.startPickingCaptions()
        #expect(part.isPickingCaptions)
        part.panelChanged(to: .captions)
        #expect(part.isPickingCaptions)
        part.panelChanged(to: .captionStyle)
        #expect(!part.isPickingCaptions)
    }

    @Test func theLinesAreTimedAgainOnlyWhenLinesOrCutsChange() {
        #expect(part.editedCaptionLines.count == 2)
        #expect(part.captionMapStore != nil)
        let before = host.document.edit
        host.document.changeEdit { $0.showsCaptions = false }
        part.editChanged(from: before)
        #expect(part.captionMapStore != nil)
        let shown = host.document.edit
        host.document.changeEdit { $0.captions.removeLast() }
        part.editChanged(from: shown)
        #expect(part.captionMapStore == nil)
        #expect(part.editedCaptionLines.count == 1)
    }

    /// A part can outlive its editor for a moment (a job finishing after the editor closed): it still has its document and
    /// jobs, and nothing to play or pick.
    @Test func aPartOutlivingItsEditorStaysSafe() throws {
        var editor: FakeEditorHost? = FakeEditorHost(edit: host.document.edit)
        let orphan = Self.makePart(try #require(editor).session)
        weak let gone = editor
        editor = nil
        #expect(gone == nil)
        #expect(!orphan.isReady)
        let id = orphan.edit.captions[0].id
        orphan.pickCaptionLine(id, at: 4)
        #expect(orphan.selection == nil)
        orphan.setCaptionText(id, "Still kept")
        #expect(orphan.edit.captions[0].text == "Still kept")
    }
}
