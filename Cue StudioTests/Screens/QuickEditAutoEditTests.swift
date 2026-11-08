//
//  QuickEditAutoEditTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

/// Auto edit (E5): listening changes nothing; the run is one undo step; Cancel while it runs leaves the edit as it was; each
/// step turns off alone (its cuts come back, its captions hide, its zooms go) without touching the rest; Before | After.
@MainActor
struct QuickEditAutoEditTests {
    private struct Scenario {
        let viewModel: QuickEditViewModel
        let editor: FakeTakeEditor
    }

    private func makeScenario(captionDelay: Duration? = nil) async -> Scenario {
        var take = TestData.take(scriptID: nil, number: 1)
        take.duration = 64
        let takes = TakeLibraryService(repository: FakeTakeRepository(takes: [take]))
        takes.load()
        let library = ScriptLibraryService(repository: FakeScriptRepository(scripts: []))
        library.load()
        let editor = FakeTakeEditor()
        editor.captionDelay = captionDelay
        editor.captions = [
            Self.line("We grew 40% in one year", at: 2),
            Self.line("and then we kept going", at: 5),
            Self.line("We moved to Lisbon that spring", at: 14),
        ]
        let viewModel = QuickEditViewModel(
            take: takes.takes[0], takes: takes, library: library, editing: editor,
            drafts: FakeDraftStore(), toast: ToastService(), player: FakeEditPlayback(), styles: FakeTextStyleStore()
        )
        await viewModel.prepare()
        return Scenario(viewModel: viewModel, editor: editor)
    }

    private static func line(_ text: String, at start: TimeInterval) -> CaptionCue {
        let words = text.split(separator: " ").enumerated().map { index, word in
            CaptionWord(text: String(word), start: start + Double(index) * 0.4, end: start + Double(index) * 0.4 + 0.35)
        }
        return CaptionCue(words: words)
    }

    private func waitForResults(_ viewModel: QuickEditViewModel) async throws {
        for _ in 0..<300 where viewModel.autoEdit?.phase != .done {
            try await Task.sleep(for: .milliseconds(20))
        }
        #expect(viewModel.autoEdit?.phase == .done)
    }

    @Test func theMainBarOpensItWithSpeechAndCaptionsPicked() async {
        let viewModel = await makeScenario().viewModel
        #expect(viewModel.mainItems.contains { $0.id == "autoEdit" })
        viewModel.perform(.openAutoEdit)
        #expect(viewModel.sheet == .autoEdit)
        #expect(viewModel.autoEdit?.steps == [.speech, .captions], "Zoom only when the creator picks it")
    }

    @Test func oneRunIsOneUndoStep() async throws {
        let viewModel = await makeScenario().viewModel
        let before = viewModel.edit.editedDuration
        let steps = viewModel.document.history.past.count
        viewModel.openAutoEdit()
        viewModel.runAutoEdit()
        try await waitForResults(viewModel)
        let record = try #require(viewModel.edit.autoEdit)
        #expect(record.removedSuggestions.count == 2, "The two clear pauses")
        #expect(record.madeCaptions)
        #expect(!viewModel.edit.captions.isEmpty)
        #expect(viewModel.edit.showsCaptions)
        #expect(viewModel.edit.editedDuration < before)
        #expect(viewModel.edit.phraseZooms.isEmpty, "Zoom wasn't picked")
        #expect(viewModel.document.history.past.count == steps + 1)
        viewModel.closeAutoEdit()
        viewModel.undo()
        #expect(viewModel.edit.captions.isEmpty)
        #expect(viewModel.edit.editedDuration == before)
        #expect(viewModel.edit.autoEdit == nil)
    }

    @Test func cancelWhileItMakesCaptionsLeavesTheEditAsItWas() async throws {
        let viewModel = await makeScenario(captionDelay: .seconds(5)).viewModel
        let before = viewModel.edit
        let steps = viewModel.document.history.past.count
        viewModel.openAutoEdit()
        viewModel.runAutoEdit()
        for _ in 0..<200 where viewModel.autoEdit?.phase != .working(.captions) {
            try await Task.sleep(for: .milliseconds(20))
        }
        #expect(viewModel.autoEdit?.phase == .working(.captions))
        viewModel.cancelAutoEdit()
        #expect(viewModel.autoEdit?.phase == .choosing)
        try await Task.sleep(for: .milliseconds(200))
        #expect(viewModel.edit.captions.isEmpty)
        #expect(viewModel.edit.timeline == before.timeline)
        #expect(viewModel.edit.autoEdit == nil)
        #expect(viewModel.document.history.past.count == steps)
    }

    @Test func eachStepTurnsOffAloneAndKeepsTheCreatorsOwn() async throws {
        let viewModel = await makeScenario().viewModel
        let own = PhraseZoom(span: TimeSpan(start: 40, end: 42), strength: .strong)
        viewModel.changeEdit { $0.phraseZooms = [own] }
        let before = viewModel.edit.editedDuration
        viewModel.openAutoEdit()
        viewModel.autoEdit?.set(.zoom, on: true)
        viewModel.runAutoEdit()
        try await waitForResults(viewModel)
        let record = try #require(viewModel.edit.autoEdit)
        #expect(!record.zoomIDs.isEmpty, "The 40% line, at least")
        #expect(viewModel.edit.phraseZooms.count == record.zoomIDs.count + 1)
        let lines = viewModel.edit.captions.count

        viewModel.turnOffAutoEditStep(.zoom)
        #expect(viewModel.edit.phraseZooms == [own], "Only the run's zooms go")
        #expect(viewModel.edit.captions.count == lines)

        viewModel.turnOffAutoEditStep(.speech)
        #expect(viewModel.edit.editedDuration == before, "The cuts came back")
        #expect(viewModel.edit.showsCaptions)

        viewModel.turnOffAutoEditStep(.captions)
        #expect(!viewModel.edit.showsCaptions)
        #expect(viewModel.edit.captions.count == lines, "The lines stay, hidden")
        #expect(viewModel.edit.autoEdit?.offSteps == [.zoom, .speech, .captions])
        viewModel.undo()
        #expect(viewModel.edit.showsCaptions, "Turning a step off is its own undo step")
    }

    @Test func aVideoWithCaptionsKeepsThem() async throws {
        let viewModel = await makeScenario().viewModel
        let mine = CaptionCue(text: "my own line", start: 1, end: 3, origin: .manual)
        viewModel.changeEdit { $0.captions = [mine] }
        viewModel.openAutoEdit()
        #expect(viewModel.autoEdit?.steps == [.speech])
        #expect(!viewModel.autoEditCanMakeCaptions)
        viewModel.runAutoEdit()
        try await waitForResults(viewModel)
        #expect(viewModel.edit.captions.map(\.text) == ["my own line"])
        #expect(viewModel.edit.autoEdit?.madeCaptions == false)
    }

    @Test func beforeAndAfterCompareTheRun() async throws {
        let viewModel = await makeScenario().viewModel
        let before = viewModel.edit.editedDuration
        viewModel.openAutoEdit()
        viewModel.runAutoEdit()
        try await waitForResults(viewModel)
        let after = viewModel.edit.editedDuration
        #expect(viewModel.canCompareAutoEdit)
        viewModel.showAutoEditBefore(true)
        #expect(viewModel.edit.editedDuration == before)
        #expect(viewModel.autoEditResult(.speech).contains("2"), "Before still says what the run did")
        #expect(!viewModel.autoEditResult(.captions).hasPrefix("0"))
        viewModel.showAutoEditBefore(false)
        #expect(viewModel.edit.editedDuration == after)
        viewModel.showAutoEditBefore(true)
        viewModel.closeAutoEdit()
        #expect(viewModel.edit.editedDuration == after, "Closing on Before goes back to After")
    }

    @Test func reopeningShowsTheLastRun() async throws {
        let viewModel = await makeScenario().viewModel
        viewModel.openAutoEdit()
        viewModel.runAutoEdit()
        try await waitForResults(viewModel)
        viewModel.closeAutoEdit()
        viewModel.openAutoEdit()
        #expect(viewModel.autoEdit?.phase == .done)
        #expect(viewModel.autoEditResult(.speech).contains("2"))
    }
}
