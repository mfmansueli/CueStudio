//
//  QuickEditCaptionFindTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

/// Find and replace in the editor: matches in play order, one replaced or all of them in one undo step, the lines' times
/// and the voice's word times kept, cut lines left alone.
@MainActor
@Suite("Quick edit caption find and replace")
struct QuickEditCaptionFindTests {
    private func makeViewModel(lines: [CaptionCue]) async -> (QuickEditViewModel, ToastService) {
        var take = TestData.take(scriptID: nil, number: 3)
        take.duration = 64
        let takes = TakeLibraryService(repository: FakeTakeRepository(takes: [take]))
        takes.load()
        let library = ScriptLibraryService(repository: FakeScriptRepository(scripts: []))
        library.load()
        let toast = ToastService()
        let viewModel = QuickEditViewModel(
            take: takes.takes[0], takes: takes, library: library, editing: FakeTakeEditor(),
            drafts: FakeDraftStore(), toast: toast, player: FakeEditPlayback(),
            mediaImporter: FakeMediaImporter(), recorder: FakeVoiceRecorder(), styles: FakeTextStyleStore()
        )
        await viewModel.prepare()
        viewModel.changeEdit {
            $0.captions = lines
            $0.showsCaptions = true
        }
        return (viewModel, toast)
    }

    private func heard(_ words: [(String, TimeInterval, TimeInterval)]) -> CaptionCue {
        CaptionCue(words: words.map { CaptionWord(text: $0.0, start: $0.1, end: $0.2) })
    }

    @Test func matchesFollowThePlayOrder() async {
        let late = CaptionCue(text: "cue again", start: 5, end: 6)
        let early = CaptionCue(text: "Cue first", start: 1, end: 2)
        let (viewModel, _) = await makeViewModel(lines: [late, early])
        #expect(viewModel.captionMatches(for: "cue").map(\.cueID) == [early.id, late.id])
    }

    @Test func oneMatchIsReplacedAndTheTimesStay() async {
        let line = heard([("the", 1, 1.2), ("cat", 1.3, 1.6), ("and", 1.7, 1.9), ("the", 2, 2.2), ("dog", 2.3, 2.6)])
        let (viewModel, toast) = await makeViewModel(lines: [line])
        let steps = viewModel.history.past.count
        let second = viewModel.captionMatches(for: "the")[1]
        viewModel.replaceCaptionMatch(second, query: "the", with: "a")
        let replaced = viewModel.edit.captions[0]
        #expect(replaced.text == "the cat and a dog")
        #expect(replaced.start == 1 && replaced.end == 2.6)
        // The words that still match keep the voice's times.
        #expect(replaced.words.first { $0.text == "dog" }?.start == 2.3)
        #expect(replaced.isRevised)
        #expect(viewModel.history.past.count == steps + 1)
        #expect(toast.message == "Replaced")
    }

    @Test func replaceAllIsOneUndoStep() async {
        let lines = [
            CaptionCue(text: "Cue studio is great", start: 0, end: 1),
            CaptionCue(text: "nothing", start: 1, end: 2),
            CaptionCue(text: "I love cue studio", start: 2, end: 3),
        ]
        let (viewModel, toast) = await makeViewModel(lines: lines)
        let steps = viewModel.history.past.count
        #expect(viewModel.replaceAllCaptionMatches("cue studio", with: "Cue Studio") == 2)
        #expect(viewModel.edit.captions.map(\.text) == ["Cue Studio is great", "nothing", "I love Cue Studio"])
        #expect(viewModel.edit.captions.map(\.start) == [0, 1, 2])
        #expect(viewModel.history.past.count == steps + 1)
        #expect(toast.message == "Replaced 2 times")
        #expect(toast.action != nil)
        viewModel.undo()
        #expect(viewModel.edit.captions.map(\.text) == lines.map(\.text))
    }

    @Test func nothingToReplaceChangesNothing() async {
        let (viewModel, _) = await makeViewModel(lines: [CaptionCue(text: "hello", start: 0, end: 1)])
        let steps = viewModel.history.past.count
        #expect(viewModel.replaceAllCaptionMatches("bye", with: "hi") == 0)
        #expect(viewModel.replaceAllCaptionMatches("hello", with: "hello") == 1)
        #expect(viewModel.history.past.count == steps)
    }

    @Test func linesInCutPartsAreLeftAlone() async {
        let kept = CaptionCue(text: "keep cue", start: 1, end: 2)
        let cut = CaptionCue(text: "cut cue", start: 20, end: 21)
        let (viewModel, _) = await makeViewModel(lines: [kept, cut])
        var timeline = viewModel.edit.timeline
        let removed = timeline.removeEdited(19...22)
        #expect(removed)
        viewModel.commit(timeline)
        #expect(viewModel.captionMatches(for: "cue").map(\.cueID) == [kept.id])
        viewModel.replaceAllCaptionMatches("cue", with: "Cue")
        #expect(viewModel.edit.captions.first { $0.id == cut.id }?.text == "cut cue")
        #expect(viewModel.edit.captions.first { $0.id == kept.id }?.text == "keep Cue")
    }

    @Test func findOpensOverTheEditorOnlyWithLines() async {
        let (empty, _) = await makeViewModel(lines: [])
        empty.perform(.findInCaptions)
        #expect(empty.sheet == nil)
        let (viewModel, _) = await makeViewModel(lines: [CaptionCue(text: "hello", start: 0, end: 1)])
        viewModel.perform(.findInCaptions)
        #expect(viewModel.sheet == .findInCaptions)
    }
}
