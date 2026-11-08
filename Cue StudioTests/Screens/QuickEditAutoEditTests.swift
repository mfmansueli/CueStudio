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

    @Test func punchInOnTheCutsTheSpeechLeftTurnsOffAlone() async throws {
        let viewModel = await makeScenario().viewModel
        viewModel.openAutoEdit()
        #expect(viewModel.autoEdit?.isOn(.punchIn) == false, "Only when the creator picks it (F16)")
        viewModel.autoEdit?.set(.punchIn, on: true)
        viewModel.autoEdit?.zoomStrength = .strong
        viewModel.runAutoEdit()
        try await waitForResults(viewModel)
        #expect(viewModel.edit.cutZoom == CutZoom(strength: .strong))
        let record = try #require(viewModel.edit.autoEdit)
        #expect(record.madePunchIn)
        #expect(record.punchedClips > 0, "The pauses taken out left cuts to punch in on")
        let cuts = viewModel.edit.editedDuration
        viewModel.turnOffAutoEditStep(.punchIn)
        #expect(viewModel.edit.cutZoom == nil)
        #expect(viewModel.edit.editedDuration == cuts, "The speech's cuts stay")
    }

    @Test func runningAgainKeepsTheFirstRunTurnOffable() async throws {
        let viewModel = await makeScenario().viewModel
        let before = viewModel.edit.editedDuration
        viewModel.openAutoEdit()
        viewModel.autoEdit?.set(.captions, on: false)
        viewModel.runAutoEdit()
        try await waitForResults(viewModel)
        viewModel.autoEditAgain()
        viewModel.autoEdit?.set(.captions, on: false)
        viewModel.autoEdit?.set(.punchIn, on: true)
        viewModel.runAutoEdit()
        try await waitForResults(viewModel)
        let record = try #require(viewModel.edit.autoEdit)
        #expect(record.removedSuggestions.count == 2, "The first run's cuts are still the run's")
        #expect(record.madePunchIn)
        viewModel.turnOffAutoEditStep(.speech)
        #expect(viewModel.edit.editedDuration == before)
    }

    @Test func aVideoWithPunchInOnAlreadyKeepsTheCreatorsChoice() async throws {
        let viewModel = await makeScenario().viewModel
        viewModel.changeEdit { $0.cutZoom = CutZoom(strength: .subtle) }
        viewModel.openAutoEdit()
        #expect(!viewModel.autoEditCanPunchIn)
    }

    /// Plan §19's acceptance: on a project with the creator's own work, the run's cuts move the texts and the voice-over with
    /// the speech, and they come back with Turn off.
    @Test func theCutsMoveTheCreatorsLayersWithTheSpeech() async throws {
        let viewModel = await makeScenario().viewModel
        var title = TextOverlay(role: .title, style: .bold, span: TimeSpan(start: 14, end: 16))
        title.text = "After the pause"
        let voice = VoiceOverClip(fileName: "vo.m4a", duration: 2, anchor: 20)
        viewModel.changeEdit {
            $0.texts = [title]
            $0.voiceOvers = [voice]
        }
        let saved = viewModel.edit.editedDuration
        viewModel.openAutoEdit()
        viewModel.autoEdit?.set(.captions, on: false)
        viewModel.runAutoEdit()
        try await waitForResults(viewModel)
        #expect(saved - viewModel.edit.editedDuration > 1)
        // Texts and voice-overs of one take are pinned to its seconds: where they play in the edit moves with the cuts.
        let timeline = viewModel.edit.timeline
        let moved = try #require(viewModel.edit.texts.first)
        #expect(moved.text == "After the pause")
        let start = try #require(timeline.editedSpan(forSource: moved.span)?.start)
        // The pause at 10–12 s came out before it (the one at 30 s is after it).
        #expect(start < 13 && start > 11.99, "The text moved with the speech: \(start)")
        #expect(abs((timeline.editedSpan(forSource: moved.span)?.duration ?? 0) - 2) < 0.01, "and kept its length")
        let narration = try #require(viewModel.edit.voiceOvers.first)
        let voiceStart = try #require(timeline.editedTime(forSource: narration.anchor))
        #expect(abs(voiceStart - (start + 6)) < 0.01, "The voice-over moved with it")
        viewModel.turnOffAutoEditStep(.speech)
        let back = viewModel.edit.timeline.editedSpan(forSource: moved.span)?.start ?? 0
        #expect(abs(back - 14) < 0.05, "Turned off, the text plays where it did")
    }
}
