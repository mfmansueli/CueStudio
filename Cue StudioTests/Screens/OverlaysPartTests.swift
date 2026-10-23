//
//  OverlaysPartTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

/// What lies on the video as a part of the editor (`OverlaysViewModel`), with only a host around it: a text added at the
/// playhead is picked through the host as one undo step of the session's document, and a text dragged on the preview is left
/// out of what plays while the editor shows the preview again.
@MainActor
@Suite("Overlays part")
struct OverlaysPartTests {
    let host: FakeEditorHost
    let part: OverlaysViewModel

    init() {
        host = FakeEditorHost(edit: TakeEdit(sourceDuration: 20, aspect: .portrait))
        part = OverlaysViewModel(
            session: host.session, importer: FakeMediaImporter(), styles: FakeTextStyleStore(),
            library: ScriptLibraryService(repository: FakeScriptRepository(scripts: [])), tracker: ObjectTracker()
        )
    }

    @Test func aTextAddedAtThePlayheadIsPickedAsOneUndoStep() throws {
        host.session.player.seek(to: 4)
        part.addText(.title)
        let text = try #require(host.document.edit.texts.first)
        #expect(host.selection == .text(text.id))
        #expect(part.editedSpan(ofText: text.id)?.start == 4)
        #expect(host.document.history.past.count == 1)
        host.undo()
        #expect(host.document.edit.texts.isEmpty)
    }

    @Test func aDraggedTextIsLeftOutOfWhatPlays() throws {
        part.addText(.title)
        let id = try #require(host.document.edit.texts.first?.id)
        let shown = host.playedEditShown
        part.beginOverlayDrag(.text(id))
        #expect(host.playedEditShown == shown + 1)
        #expect(part.hidingDraggedOverlay(in: host.document.edit).texts.isEmpty)
        part.endOverlayDrag()
        #expect(host.playedEditShown == shown + 2)
        #expect(part.hidingDraggedOverlay(in: host.document.edit).texts.count == 1)
    }
}
