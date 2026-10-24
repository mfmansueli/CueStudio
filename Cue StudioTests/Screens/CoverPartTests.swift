//
//  CoverPartTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

/// The cover as a part of the editor (`CoverViewModel`), with only a host around it: Cover Studio opens with nothing else
/// picked or open, Done is one undo step of the session's document, and the cover block is drawn for what the edit shows.
@MainActor
@Suite("Cover part")
struct CoverPartTests {
    let host: FakeEditorHost
    let editing: FakeTakeEditor
    let part: CoverViewModel

    init() {
        host = FakeEditorHost(edit: TakeEdit(sourceDuration: 20, aspect: .portrait))
        editing = FakeTakeEditor()
        part = CoverViewModel(
            session: host.session, editing: editing, pictures: FakeCoverPictures(), importer: FakeMediaImporter(),
            styles: FakeTextStyleStore()
        )
    }

    @Test func theStudioOpensAloneAndDoneIsOneUndoStep() throws {
        host.selection = .caption(UUID())
        host.panel = .captions
        part.openCoverStudio()
        let studio = try #require(part.coverStudio)
        #expect(host.selection == nil)
        #expect(host.panel == nil)
        studio.setTitle("3 morning habits")
        part.finishCoverStudio(studio)
        #expect(part.coverStudio == nil)
        #expect(host.document.edit.cover?.title == "3 morning habits")
        #expect(host.document.history.past.count == 1)
    }

    @Test func theCoverBlockIsDrawnForTheEditsCover() async throws {
        part.openCoverStudio()
        let studio = try #require(part.coverStudio)
        studio.setTitle("Drawn")
        part.finishCoverStudio(studio)
        part.editChanged()
        #expect(part.isDrawingCover)
        await host.session.jobs.finished(.cover)
        #expect(!part.isDrawingCover)
        #expect(part.drawnCoverKey == host.document.edit.coverDrawingKey)
    }
}
