//
//  QuickEditCaptionsTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

/// Captions in Quick edit: made from the voice with or without a script, stoppable, never invented
/// when nothing can be heard, asking before replacing corrected lines, and corrected line by line
/// as undo steps.
@MainActor
@Suite("Quick edit captions")
struct QuickEditCaptionsTests {
    private struct Scenario {
        let viewModel: QuickEditViewModel
        let editor: FakeTakeEditor
        let player: FakeEditPlayback
        let toast: ToastService
    }

    private func makeScenario(
        script: Script? = TestData.script(text: "Okay, real talk."), editor: FakeTakeEditor = FakeTakeEditor()
    ) async -> Scenario {
        var take = TestData.take(scriptID: script?.id, number: 3)
        take.duration = 64
        let takes = TakeLibraryService(repository: FakeTakeRepository(takes: [take]))
        takes.load()
        let library = ScriptLibraryService(repository: FakeScriptRepository(scripts: script.map { [$0] } ?? []))
        library.load()
        let player = FakeEditPlayback()
        let toast = ToastService()
        let viewModel = QuickEditViewModel(
            take: takes.takes[0], takes: takes, library: library, editing: editor,
            drafts: FakeDraftStore(), toast: toast, player: player,
            mediaImporter: FakeMediaImporter(), recorder: FakeVoiceRecorder(), styles: FakeTextStyleStore()
        )
        await viewModel.prepare()
        return Scenario(viewModel: viewModel, editor: editor, player: player, toast: toast)
    }

    /// Waits for the listening started by `makeCaptions`.
    private func finish(_ viewModel: QuickEditViewModel) async {
        await viewModel.captionTask?.value
    }

    // MARK: - Making captions

    @Test func captionsComeFromTheVoiceAsOneUndoStep() async {
        let scenario = await makeScenario()
        let viewModel = scenario.viewModel
        let steps = viewModel.history.past.count
        viewModel.makeCaptions()
        #expect(viewModel.captionState.isWorking)
        await finish(viewModel)
        #expect(viewModel.captionState == .idle)
        #expect(viewModel.edit.captions.map(\.text) == ["Okay, real talk."])
        #expect(viewModel.edit.captions[0].hasWordTiming)
        #expect(viewModel.edit.captionTranscript?.words.count == 3)
        #expect(viewModel.edit.showsCaptions)
        #expect(viewModel.history.past.count == steps + 1)
        #expect(scenario.toast.message == "Captions made from your voice")
    }

    @Test func aTakeWithoutAScriptIsCaptionedFromItsVoice() async {
        let scenario = await makeScenario(script: nil)
        await scenario.viewModel.setShowsCaptions(true)
        #expect(scenario.editor.captionScript == "")
        #expect(scenario.viewModel.edit.captions.count == 1)
    }

    @Test func noSpeechMakesNoLinesAndKeepsTheOnesThere() async {
        let editor = FakeTakeEditor()
        let scenario = await makeScenario(editor: editor)
        let viewModel = scenario.viewModel
        viewModel.makeCaptions()
        await finish(viewModel)
        let lines = viewModel.edit.captions
        editor.captionOutcome = .noSpeech
        viewModel.makeCaptions()
        await finish(viewModel)
        #expect(viewModel.captionState == .noSpeech)
        #expect(viewModel.edit.captions == lines)
        #expect(viewModel.captionState.message == "No speech found in this take.")
    }

    @Test func aLanguageThePhoneCantHearIsSaidNeverSwapped() async {
        let editor = FakeTakeEditor()
        editor.captionOutcome = .unavailable(.unsupported(.thai))
        let scenario = await makeScenario(editor: editor)
        let viewModel = scenario.viewModel
        viewModel.setCaptionLanguage(.thai)
        viewModel.makeCaptions()
        await finish(viewModel)
        #expect(editor.captionLanguage == .language(.thai))
        #expect(viewModel.edit.captions.isEmpty)
        #expect(viewModel.captionState == .unavailable(.unsupported(.thai)))
        #expect(viewModel.captionState.message?.hasPrefix("Captions can’t listen in") == true)
        // Lines can still be written by hand.
        viewModel.addCaption()
        #expect(viewModel.edit.captions.first?.origin == .manual)
        #expect(viewModel.editingCaptionID == viewModel.edit.captions.first?.id)
    }

    @Test func aTakeWithoutSoundSaysSo() async {
        let editor = FakeTakeEditor()
        editor.captionOutcome = .noAudio
        let scenario = await makeScenario(editor: editor)
        scenario.viewModel.makeCaptions()
        await finish(scenario.viewModel)
        #expect(scenario.viewModel.captionState == .noAudio)
    }

    @Test func aFailureCanBeTriedAgain() async {
        let editor = FakeTakeEditor()
        editor.captionFails = true
        let scenario = await makeScenario(editor: editor)
        scenario.viewModel.makeCaptions()
        await finish(scenario.viewModel)
        #expect(scenario.viewModel.captionState == .failed)
        #expect(scenario.viewModel.captionState.canRetry)
        editor.captionFails = false
        scenario.viewModel.makeCaptions()
        await finish(scenario.viewModel)
        #expect(scenario.viewModel.edit.captions.count == 1)
    }

    @Test func stoppingKeepsTheLinesAndALateResultIsDropped() async {
        let editor = FakeTakeEditor()
        let scenario = await makeScenario(editor: editor)
        let viewModel = scenario.viewModel
        editor.captionDelay = .seconds(5)
        viewModel.makeCaptions()
        #expect(viewModel.captionState.isWorking)
        viewModel.cancelCaptions()
        #expect(viewModel.captionState == .cancelled)
        await finish(viewModel)
        #expect(viewModel.edit.captions.isEmpty)
        #expect(viewModel.captionState == .cancelled)
    }

    @Test func changingTheLanguageStopsListeningInTheOldOne() async {
        let editor = FakeTakeEditor()
        let scenario = await makeScenario(editor: editor)
        let viewModel = scenario.viewModel
        editor.captionDelay = .seconds(5)
        viewModel.makeCaptions()
        viewModel.setCaptionLanguage(.portugueseBrazil)
        await finish(viewModel)
        // The English result never lands on the Portuguese choice.
        #expect(viewModel.edit.captions.isEmpty)
        #expect(viewModel.edit.captionLanguage == .portugueseBrazil)
        #expect(viewModel.captionState == .idle)
    }

    @Test func correctedLinesAreOnlyReplacedAfterAsking() async {
        let editor = FakeTakeEditor()
        let scenario = await makeScenario(editor: editor)
        let viewModel = scenario.viewModel
        viewModel.makeCaptions()
        await finish(viewModel)
        let id = viewModel.edit.captions[0].id
        viewModel.setCaptionText(id, "Okay, REAL talk.")
        viewModel.makeCaptions()
        #expect(viewModel.confirmsCaptionReplacement)
        #expect(editor.captionRequests == 1)
        #expect(viewModel.edit.captions[0].text == "Okay, REAL talk.")

        viewModel.makeCaptions(replacingRevised: true)
        await finish(viewModel)
        #expect(editor.captionRequests == 2)
        #expect(viewModel.edit.captions[0].text == "Okay, real talk.")
    }

    @Test func theLanguagePickedForTheTakeIsTheOneHeard() async {
        let editor = FakeTakeEditor()
        let scenario = await makeScenario(editor: editor)
        scenario.viewModel.setCaptionLanguage(.japanese)
        scenario.viewModel.makeCaptions()
        await finish(scenario.viewModel)
        #expect(editor.captionLanguage == .language(.japanese))
        scenario.viewModel.setCaptionLanguage(nil)
        scenario.viewModel.makeCaptions(replacingRevised: true)
        await finish(scenario.viewModel)
        #expect(editor.captionLanguage == scenario.viewModel.speechLanguage)
    }

    // MARK: - Correcting

    @Test func aCorrectionKeepsTheVoicesTimesAndTheOriginal() async {
        let scenario = await makeScenario()
        let viewModel = scenario.viewModel
        viewModel.makeCaptions()
        await finish(viewModel)
        let line = viewModel.edit.captions[0]
        viewModel.beginChange()
        viewModel.setCaptionText(line.id, "Okay, real talk")
        viewModel.setCaptionText(line.id, "Okay, real talk!")
        viewModel.endChange()
        let fixed = viewModel.edit.captions[0]
        #expect(fixed.text == "Okay, real talk!")
        #expect(fixed.words.map(\.start) == line.words.map(\.start))
        #expect(fixed.isRevised)
        #expect(viewModel.heardText(of: fixed) == "Okay, real talk.")
        viewModel.undo()
        #expect(viewModel.edit.captions[0].text == "Okay, real talk.")
    }

    @Test func splitMergeAndDeleteAreUndoable() async {
        let scenario = await makeScenario()
        let viewModel = scenario.viewModel
        viewModel.makeCaptions()
        await finish(viewModel)
        let id = viewModel.edit.captions[0].id
        viewModel.splitCaption(id, beforeWord: 1)
        #expect(viewModel.edit.captions.map(\.text) == ["Okay,", "real talk."])
        viewModel.mergeCaptionWithNext(id)
        #expect(viewModel.edit.captions.map(\.text) == ["Okay, real talk."])
        viewModel.deleteCaption(id)
        #expect(viewModel.edit.captions.isEmpty)
        viewModel.undo()
        viewModel.undo()
        #expect(viewModel.edit.captions.count == 2)
    }

    @Test func nudgingALineMovesItInTheEditAndStaysInsideItsNeighbors() async {
        let scenario = await makeScenario()
        let viewModel = scenario.viewModel
        viewModel.makeCaptions()
        await finish(viewModel)
        let id = viewModel.edit.captions[0].id
        viewModel.nudgeCaption(id, edge: .start, by: -0.5)
        #expect(viewModel.edit.captions[0].start == 0)
        viewModel.nudgeCaption(id, edge: .end, by: 0.5)
        #expect(abs(viewModel.edit.captions[0].end - 1.5) < 0.000_1)
        #expect(viewModel.edit.captions[0].isRevised)
    }

    @Test func anEmptyLineWrittenByHandIsDroppedWhenItsSheetCloses() async {
        let scenario = await makeScenario()
        scenario.viewModel.addCaption()
        #expect(scenario.viewModel.edit.captions.count == 1)
        scenario.viewModel.endEditingCaption()
        #expect(scenario.viewModel.edit.captions.isEmpty)
    }

    @Test func cutsShowOnlyTheWordsStillInTheEdit() async {
        let scenario = await makeScenario()
        let viewModel = scenario.viewModel
        viewModel.makeCaptions()
        await finish(viewModel)
        // "real" is said from 0.35 to 0.6.
        var timeline = viewModel.edit.timeline
        timeline.remove([TimeSpan(start: 0.32, end: 0.63)])
        viewModel.commit(timeline)
        let line = viewModel.edit.editedCaptions[0]
        #expect(line.text == "Okay, talk.")
        #expect(line.id == viewModel.edit.captions[0].id)
        #expect(viewModel.edit.captions[0].text == "Okay, real talk.")
    }
}
