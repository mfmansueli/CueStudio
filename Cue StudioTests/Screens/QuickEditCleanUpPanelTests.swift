//
//  QuickEditCleanUpPanelTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

/// Clean up on the design's demo take (four pauses, 21.6 s): one panel with Pauses · Words · Text, opened on Pauses or on Text,
/// the marks kept across tabs and forgotten when it closes, ✓ never removing, the time saved counted once, Remove naming what
/// it removes with Undo on its toast, Put back one at a time, Gap left, and the start row.
@MainActor
@Suite("Quick edit · Clean up")
struct QuickEditCleanUpPanelTests {
    private struct Scenario {
        let viewModel: QuickEditViewModel
        let toast: ToastService
        let editor: FakeTakeEditor
    }

    private func makeScenario(_ shape: (inout TakeEdit) -> Void = { _ in }, editor: FakeTakeEditor = FakeTakeEditor()) async -> Scenario {
        var take = TestData.take(scriptID: nil, number: 3)
        take.duration = SampleEdit.duration
        var edit = SampleEdit.make(aspect: take.aspect)
        shape(&edit)
        take.edit = edit
        let takes = TakeLibraryService(repository: FakeTakeRepository(takes: [take]))
        takes.load()
        let library = ScriptLibraryService(repository: FakeScriptRepository(scripts: []))
        library.load()
        editor.duration = SampleEdit.duration
        let toast = ToastService()
        let viewModel = QuickEditViewModel(
            take: takes.takes[0], takes: takes, library: library, editing: editor,
            drafts: FakeDraftStore(), toast: toast, player: FakeEditPlayback(),
            mediaImporter: FakeMediaImporter(), recorder: FakeVoiceRecorder(), styles: FakeTextStyleStore()
        )
        await viewModel.prepare()
        return Scenario(viewModel: viewModel, toast: toast, editor: editor)
    }

    // MARK: - Tabs

    @Test func pausesOpensOnPausesAndEditByTextOnTextTall() async {
        let viewModel = await makeScenario().viewModel
        viewModel.perform(.open(.pauses))
        #expect(viewModel.panel == .pauses)
        #expect(viewModel.clips.cleanUpTab == .pauses)
        #expect(!viewModel.panelIsExpanded)
        viewModel.closePanel()
        viewModel.perform(.editByText)
        #expect(viewModel.panel == .pauses)
        #expect(viewModel.clips.cleanUpTab == .transcript)
        #expect(viewModel.panelIsExpanded)
        #expect(viewModel.sheet == nil)
        // Closed and opened again from its tool: Pauses, at its usual height.
        viewModel.closePanel()
        viewModel.perform(.open(.pauses))
        #expect(viewModel.clips.cleanUpTab == .pauses)
        #expect(!viewModel.panelIsExpanded)
    }

    @Test func switchingTabsKeepsTheMarksAndTheHeight() async {
        let viewModel = await makeScenario().viewModel
        viewModel.perform(.open(.pauses))
        let kept = viewModel.clips.pauseCandidates[0]
        viewModel.clips.toggleMark(kept.id)
        viewModel.clips.showCleanUpTab(.words)
        #expect(viewModel.clips.cleanUpTab == .words)
        viewModel.clips.showCleanUpTab(.transcript)
        #expect(viewModel.panelIsExpanded)
        // Back on Pauses: still tall, still kept.
        viewModel.clips.showCleanUpTab(.pauses)
        #expect(viewModel.panelIsExpanded)
        #expect(!viewModel.clips.isMarked(kept))
        // Edit by text while open just shows Text.
        viewModel.perform(.editByText)
        #expect(viewModel.clips.cleanUpTab == .transcript)
        #expect(!viewModel.clips.isMarked(kept))
    }

    @Test func closingAppliesNothingAndForgetsTheMarks() async {
        let viewModel = await makeScenario().viewModel
        viewModel.perform(.open(.pauses))
        let kept = viewModel.clips.pauseCandidates[0]
        viewModel.clips.toggleMark(kept.id)
        let steps = viewModel.document.history.past.count
        viewModel.closePanel()
        #expect(abs(viewModel.edit.editedDuration - 21.6) < 0.001)
        #expect(viewModel.document.history.past.count == steps)
        #expect(viewModel.edit.suggestions.allSatisfy { $0.status == .pending })
        viewModel.perform(.open(.pauses))
        #expect(viewModel.clips.isMarked(kept))
    }

    // MARK: - Remove

    @Test func overlappingMarksSaveEachSecondOnce() async {
        // A sure "um" across the first pause's end (4.12–5.08): 4.5–5.5.
        let viewModel = await makeScenario { edit in
            edit.suggestions.append(CleanUpSuggestion(kind: .filler, span: TimeSpan(start: 4.5, end: 5.5), text: "um", confidence: 0.9))
        }.viewModel
        viewModel.perform(.open(.pauses))
        #expect(viewModel.clips.markedCleanUp.count == 5)
        // 4.06 s of pauses, plus the 0.42 s of the "um" past the pause: 4.48, not 5.06.
        #expect(abs(viewModel.clips.cleanUpSaving - 4.48) < 0.001)
        #expect(viewModel.clips.cleanUpApplyLabel == "Remove pauses and hesitations")
        viewModel.clips.applyCleanUp()
        #expect(abs(viewModel.edit.editedDuration - (21.6 - 4.48)) < 0.001)
    }

    @Test func theButtonNamesWhatItRemoves() async {
        let viewModel = await makeScenario { edit in
            edit.suggestions.append(CleanUpSuggestion(kind: .filler, span: TimeSpan(start: 7, end: 7.3), text: "um", confidence: 0.9))
            edit.suggestions.append(CleanUpSuggestion(kind: .retake, span: TimeSpan(start: 12, end: 13), confidence: 0.5))
        }.viewModel
        viewModel.perform(.open(.pauses))
        #expect(viewModel.clips.cleanUpApplyLabel == "Remove pauses and hesitations")
        let retake = viewModel.clips.wordCandidates.first { $0.kind == .retake }
        viewModel.clips.toggleMark(retake?.id ?? UUID())
        #expect(viewModel.clips.cleanUpApplyLabel == "Remove pauses, hesitations and repeats")
        for pause in viewModel.clips.pauseCandidates { viewModel.clips.toggleMark(pause.id) }
        #expect(viewModel.clips.cleanUpApplyLabel == "Remove hesitations and repeats")
    }

    @Test func removeHasUndoOnItsToast() async throws {
        let scenario = await makeScenario()
        scenario.viewModel.perform(.open(.pauses))
        scenario.viewModel.clips.applyCleanUp()
        #expect(scenario.toast.message == "Removed 4 pauses · \(TestData.decimal("4.1"))s")
        let undo = try #require(scenario.toast.action)
        undo.perform()
        #expect(abs(scenario.viewModel.edit.editedDuration - 21.6) < 0.001)
    }

    // MARK: - Put back

    @Test func onePausePutBackAloneWithUndo() async throws {
        let scenario = await makeScenario()
        let viewModel = scenario.viewModel
        viewModel.perform(.open(.pauses))
        viewModel.clips.applyCleanUp()
        viewModel.perform(.open(.pauses))
        let removed = viewModel.clips.removedPauses
        #expect(removed.count == 4)
        let second = removed[1]
        viewModel.clips.putBack(second)
        // 0.86 s back; the other three stay out.
        #expect(abs(viewModel.edit.editedDuration - (21.6 - 4.06 + 0.86)) < 0.001)
        #expect(viewModel.clips.removedPauses.count == 3)
        #expect(viewModel.edit.suggestions.first { $0.id == second.suggestion.id }?.status == .kept)
        #expect(viewModel.clips.pauseCandidates.contains { $0.id == second.suggestion.id })
        #expect(scenario.toast.message == "Pause put back · +\(TestData.decimal("0.9"))s")
        try #require(scenario.toast.action).perform()
        #expect(abs(viewModel.edit.editedDuration - (21.6 - 4.06)) < 0.001)
        #expect(viewModel.clips.removedPauses.count == 4)
    }

    @Test func aMovedClipStillTakesItsPauseBack() async throws {
        let viewModel = await makeScenario().viewModel
        viewModel.perform(.open(.pauses))
        viewModel.clips.applyCleanUp()
        // The first clip (0–4.12) moved to the end.
        viewModel.change { $0.timeline.moveSegment(from: 0, to: $0.timeline.segments.count - 1) }
        let first = try #require(viewModel.clips.removedPauses.first { $0.span.start < 5 })
        #expect(first.place != nil)
        let before = viewModel.edit.editedDuration
        viewModel.clips.putBack(first)
        #expect(abs(viewModel.edit.editedDuration - before - 0.96) < 0.001)
    }

    @Test func aDeletedNeighbourSaysWhyItCantComeBack() async throws {
        let viewModel = await makeScenario().viewModel
        viewModel.perform(.open(.pauses))
        viewModel.clips.applyCleanUp()
        // The clips on both sides of the second pause (4.12–9.12 and 9.98–16.32) moved apart and deleted.
        viewModel.change { snapshot in
            snapshot.timeline.moveSegment(from: 0, to: snapshot.timeline.segments.count - 1)
            let gone = snapshot.timeline.segments.filter { $0.sourceStart > 4 && $0.sourceStart < 10 }
            for segment in gone { snapshot.timeline.removeSegment(id: segment.id) }
        }
        let blocked = try #require(viewModel.clips.removedPauses.first { abs($0.span.start - 9.12) < 0.01 })
        #expect(blocked.place == nil)
        #expect(blocked.block == .clipsGone)
        #expect(viewModel.clips.removedDetail(blocked).hasPrefix("Can't put back"))
    }

    // MARK: - Gap left

    @Test func theGapChangesWhatIsCutNextNeverWhatWasCut() async {
        let viewModel = await makeScenario().viewModel
        viewModel.perform(.open(.pauses))
        #expect(viewModel.edit.pauseGap == .natural)
        viewModel.clips.pauseGap = .tight
        // 0.12 s more of each pause; the last one ends the take, so only its start moves.
        #expect(abs(viewModel.clips.cleanUpSaving - 4.48) < 0.001)
        viewModel.clips.pauseGap = .relaxed
        #expect(abs(viewModel.clips.cleanUpSaving - 3.5) < 0.001)
        viewModel.clips.applyCleanUp()
        let after = viewModel.edit.editedDuration
        #expect(abs(after - (21.6 - 3.5)) < 0.001)
        viewModel.perform(.open(.pauses))
        viewModel.clips.pauseGap = .tight
        #expect(abs(viewModel.edit.editedDuration - after) < 0.001)
        #expect(abs(viewModel.clips.removedPauses.reduce(0) { $0 + $1.span.duration } - 3.5) < 0.001)
    }

    // MARK: - Start

    @Test func theStartRowTrimsWithUndo() async throws {
        let scenario = await makeScenario { edit in
            edit.texts = []
            edit.captionTranscript = nil
            // 1.2 s of silence before the first sound.
            edit.suggestions.append(CleanUpSuggestion(kind: .pause, span: TimeSpan(start: 0.12, end: 1.08), confidence: 0.9))
        }
        let viewModel = scenario.viewModel
        viewModel.perform(.open(.pauses))
        let proposal = try #require(viewModel.clips.cleanUpStart)
        #expect(abs(proposal.saving - 1.0) < 0.001)
        // Not a card too.
        #expect(viewModel.clips.pauseCandidates.count == 4)
        viewModel.clips.trimToFirstWord()
        #expect(abs(viewModel.edit.editedDuration - 20.6) < 0.001)
        try #require(scenario.toast.action).perform()
        #expect(abs(viewModel.edit.editedDuration - 21.6) < 0.001)
    }

    @Test func aTitleOnTheStartKeepsTheStart() async throws {
        let viewModel = await makeScenario { edit in
            edit.captionTranscript = nil
            edit.suggestions.append(CleanUpSuggestion(kind: .pause, span: TimeSpan(start: 0.12, end: 1.08), confidence: 0.9))
        }.viewModel
        viewModel.perform(.open(.pauses))
        // The demo's title starts at 0.2 s.
        let proposal = try #require(viewModel.clips.cleanUpStart)
        #expect(proposal.keepsIntro)
        viewModel.clips.trimToFirstWord()
        #expect(abs(viewModel.edit.editedDuration - 21.6) < 0.001)
    }

    // MARK: - What Words says

    @Test func wordsSayWhyTheyMayBeMissing() async {
        let editor = FakeTakeEditor()
        editor.transcript = nil
        let unheard = await makeScenario({ $0.cleanUpAnalyzed = false }, editor: editor).viewModel
        await unheard.clips.analyzeIfNeeded()
        #expect(unheard.clips.analysis == .done)
        #expect(unheard.clips.wordsNote == "Cue couldn't hear the words of this take on this iPhone. Pauses still work.")

        let japanese = FakeTakeEditor()
        japanese.transcript = TakeTranscript(words: [TimedWord(text: "今日", start: 1, end: 1.3)], languageCode: "ja")
        let other = await makeScenario({ $0.cleanUpAnalyzed = false }, editor: japanese).viewModel
        await other.clips.analyzeIfNeeded()
        #expect(other.clips.wordsNote == "Ums: English, Portuguese and Spanish. Pauses work in every language.")
    }

    @Test func aNoisyTakeIsInconclusive() async {
        let editor = FakeTakeEditor()
        editor.cleanUpInconclusive = true
        let viewModel = await makeScenario({ $0.cleanUpAnalyzed = false }, editor: editor).viewModel
        await viewModel.clips.analyzeIfNeeded()
        #expect(viewModel.clips.cleanUpIsInconclusive)
    }

    @Test func nothingFoundOffersAShorterLength() async {
        let viewModel = await makeScenario().viewModel
        viewModel.perform(.open(.pauses))
        for _ in 0..<30 { viewModel.clips.raisePauseThreshold() }
        #expect(viewModel.clips.pauseCandidates.isEmpty)
        #expect(viewModel.clips.noPausesTitle == "No pauses longer than \(TestData.decimal("3.0"))s")
        let shorter = viewModel.clips.shorterPauseThreshold
        #expect(shorter.map { abs($0 - 2.8) < 0.001 } == true)
        for _ in 0..<30 { viewModel.clips.lowerPauseThreshold() }
        #expect(viewModel.clips.shorterPauseThreshold == nil)
    }
}
