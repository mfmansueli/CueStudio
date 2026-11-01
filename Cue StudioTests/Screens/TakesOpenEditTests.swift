//
//  TakesOpenEditTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

/// A video "In edit" in Takes opens on the take whose edit is open: its Edit goes on with that edit, never a new one on the best take.
@MainActor
@Suite("Takes · an edit left open")
struct TakesOpenEditTests {
    private func draft(for take: Take) -> QuickEditDraft {
        QuickEditDraft(
            takeID: take.id, edit: TakeEdit(sourceDuration: 30, aspect: .portrait), playhead: 0, history: EditHistory<EditSnapshot>(),
            savedAt: TestData.now
        )
    }

    /// Two edits left open: the one left last is the one to go on with.
    @Test func theEditLeftLastIsTheOneToGoOnWith() {
        let takes = (1...3).map { TestData.take(scriptID: UUID(), number: $0) }
        let drafts = FakeDraftStore()
        #expect(drafts.takeInEdit(among: takes) == nil)
        for (take, minutes) in [(takes[0], 30.0), (takes[2], 5.0)] {
            var kept = draft(for: take)
            kept.savedAt = TestData.now.addingTimeInterval(-minutes * 60)
            drafts.drafts[take.id] = kept
        }
        #expect(drafts.takeInEdit(among: takes)?.id == takes[2].id)
    }

    @Test func editAndTheInEditCardOpenTheTakeWhoseEditIsOpen() throws {
        let script = UUID()
        // The edit was left on take 1 ("Not yet"), then take 2 was recorded and starred.
        let first = TestData.take(scriptID: script, number: 1, recordedAt: TestData.now.addingTimeInterval(-600))
        let second = TestData.take(scriptID: script, number: 2, isBest: true)
        let takes = TakeLibraryService(repository: FakeTakeRepository(takes: [first, second]))
        takes.load()
        let drafts = FakeDraftStore()
        drafts.drafts[first.id] = draft(for: first)
        let presentation = PresentationService()
        let viewModel = TakesViewModel(
            takes: takes, library: ScriptLibraryService(repository: FakeScriptRepository(scripts: [])), drafts: drafts,
            presentation: presentation, toast: ToastService()
        )
        let video = try #require(viewModel.allVideos.first)
        #expect(video.stage == .edit && video.best?.id == second.id)
        viewModel.open(video, then: .edit)
        #expect(presentation.prompter?.reviewTakeID == first.id && presentation.prompter?.reviewAction == .edit)
        viewModel.open(video)
        #expect(presentation.prompter?.reviewTakeID == first.id)
        // Nothing open any more: the best take again.
        drafts.drafts = [:]
        viewModel.refresh()
        viewModel.open(try #require(viewModel.allVideos.first))
        #expect(presentation.prompter?.reviewTakeID == second.id)
    }
}
