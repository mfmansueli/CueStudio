//
//  QuickEditTimelineTracksTests.swift
//  Cue StudioTests
//

import CoreGraphics
import Foundation
import Testing
@testable import Cue_Studio

/// The shared timeline in Edit: tracks for texts, captions, media and sound on the strip's scale,
/// one bar picked at a time, Delete and Edit acting on it; and Clean Up's two sections.
@MainActor
@Suite("Quick edit timeline tracks")
struct QuickEditTimelineTracksTests {
    private struct Scenario {
        let viewModel: QuickEditViewModel
        let editor: FakeTakeEditor
        let player: FakeEditPlayback
    }

    private func makeScenario(editor: FakeTakeEditor = FakeTakeEditor()) async -> Scenario {
        let script = TestData.script(text: "Okay, real talk.")
        var take = TestData.take(scriptID: script.id, number: 3)
        take.duration = 64
        let takes = TakeLibraryService(repository: FakeTakeRepository(takes: [take]))
        takes.load()
        let library = ScriptLibraryService(repository: FakeScriptRepository(scripts: [script]))
        library.load()
        let player = FakeEditPlayback()
        let viewModel = QuickEditViewModel(
            take: takes.takes[0], takes: takes, library: library, editing: editor,
            drafts: FakeDraftStore(), toast: ToastService(), player: player,
            mediaImporter: FakeMediaImporter(), recorder: FakeVoiceRecorder(), styles: FakeTextStyleStore()
        )
        await viewModel.prepare()
        return Scenario(viewModel: viewModel, editor: editor, player: player)
    }

    private func withCaptions(_ viewModel: QuickEditViewModel) async {
        viewModel.makeCaptions()
        await viewModel.captionTask?.value
    }

    // MARK: - Tracks

    @Test func emptyTracksTakeNoRoom() async {
        let scenario = await makeScenario()
        #expect(TimelineTracksView.height(for: scenario.viewModel) == 0)
        scenario.viewModel.addText(.title)
        #expect(TimelineTracksView.height(for: scenario.viewModel) == TimelineTracksView.trackHeight + TimelineTracksView.spacing)
        await withCaptions(scenario.viewModel)
        #expect(TimelineTracksView.height(for: scenario.viewModel) == 2 * (TimelineTracksView.trackHeight + TimelineTracksView.spacing))
    }

    @Test func tracksUseTheStripsScaleAtAnyZoom() {
        var timeline = EditTimeline(sourceDuration: 60)
        timeline.trimStart(to: 5)
        for zoom in [1.0, 4.0] {
            let layout = TimelineLayout(timeline: timeline, width: 360, zoom: zoom, offset: 100)
            let scale = TrackScale(layout: layout)
            #expect(scale.x(for: 10) == layout.x(forEdited: 10))
            #expect(abs(scale.time(at: scale.x(for: 20)) - 20) < 0.05)
            #expect(scale.time(at: -500) == 0)
        }
    }

    // MARK: - Picking

    @Test func oneBarIsPickedAtATime() async {
        let scenario = await makeScenario()
        let viewModel = scenario.viewModel
        viewModel.addText(.title)
        // A new text is picked and open; let go of it first.
        viewModel.editingTextID = nil
        viewModel.clearLayerSelection()
        await withCaptions(viewModel)
        let text = viewModel.textBars[0]
        let caption = viewModel.captionBars[0]
        viewModel.selectBar(text)
        #expect(viewModel.selectedLayer?.id == text.id)
        viewModel.selectBar(caption)
        #expect(viewModel.selectedLayer?.id == caption.id)
        #expect(viewModel.selectedTextID == nil)
        // Tapping it again lets go.
        viewModel.selectBar(viewModel.captionBars[0])
        #expect(viewModel.selectedLayer == nil)
    }

    @Test func tappingTheStripLetsGoOfTheBar() async {
        let scenario = await makeScenario()
        let viewModel = scenario.viewModel
        viewModel.addText(.title)
        viewModel.selectBar(viewModel.textBars[0])
        viewModel.tapTimeline(onPiece: nil)
        #expect(viewModel.selectedLayer == nil)
    }

    @Test func deleteActsOnThePickedBar() async {
        let scenario = await makeScenario()
        let viewModel = scenario.viewModel
        viewModel.addText(.title)
        await withCaptions(viewModel)
        viewModel.selectBar(viewModel.captionBars[0])
        viewModel.deleteSelectedLayer()
        #expect(viewModel.edit.captions.isEmpty)
        #expect(viewModel.edit.texts.count == 1)
        viewModel.undo()
        #expect(viewModel.edit.captions.count == 1)
    }

    @Test func editOpensThePickedBarWhereItIsEdited() async {
        let scenario = await makeScenario()
        let viewModel = scenario.viewModel
        await withCaptions(viewModel)
        viewModel.selectBar(viewModel.captionBars[0])
        viewModel.openSelectedLayer()
        #expect(viewModel.editingCaptionID == viewModel.edit.captions[0].id)
    }

    @Test func aCaptionMovedOnItsTrackTakesItsWordsAndAsksForATimingCheck() async {
        let scenario = await makeScenario()
        let viewModel = scenario.viewModel
        await withCaptions(viewModel)
        let bar = viewModel.captionBars[0]
        viewModel.beginChange()
        viewModel.moveBar(bar, toStart: 2)
        viewModel.endChange()
        let moved = viewModel.edit.captions[0]
        #expect(abs(moved.start - 2) < 0.001)
        #expect(abs(moved.words[0].start - 2) < 0.001)
        #expect(moved.needsTimingReview)
        #expect(moved.isRevised)
        viewModel.undo()
        #expect(viewModel.edit.captions[0].start == 0)
    }

    // MARK: - Clean Up

    @Test func reviewListsWordsAndRemoveAllTakesOnlyThem() async {
        let editor = FakeTakeEditor()
        editor.silences = [TimeSpan(start: 10, end: 12)]
        editor.transcript = TakeTranscript(words: [
            TimedWord(text: "so", start: 4, end: 4.3),
            TimedWord(text: "um", start: 4.8, end: 5.2),
            TimedWord(text: "today", start: 5.6, end: 6),
        ], languageCode: "en")
        let scenario = await makeScenario(editor: editor)
        let viewModel = scenario.viewModel
        await viewModel.analyzeIfNeeded()
        // "um" is a filler wherever it comes; "so" only because of the hesitation after it, so it
        // waits for the creator.
        #expect(viewModel.wordSuggestions.map(\.kind) == [.filler, .filler])
        #expect(viewModel.wordsReviewTitle == "2 to review")
        viewModel.removeAllSureWords()
        #expect(viewModel.pendingWordSuggestions.count == 1)
        #expect(viewModel.pendingWordSuggestions.first?.title == "“so”")
        // The pause waits in its own section.
        #expect(viewModel.removablePauses.count == 1)
    }
}
