//
//  QuickEditTranscriptEditTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

/// Edit by text: words in play order, a cut that keeps the pause before the words and drops the one after, captions and what is
/// pinned to the words following the cut, put back, one undo step, and fixing a caption's text never cutting anything.
@MainActor
@Suite("Quick edit · Edit by text")
struct QuickEditTranscriptEditTests {
    /// "So today I want to show you three habits" over 0–4.5 s of a 10 s take, one word every half second (0.35 s long).
    private static let said = ["So", "today", "I", "want", "to", "show", "you", "three", "habits"]

    private func makeViewModel() async -> (QuickEditViewModel, FakeEditPlayback) {
        var take = TestData.take(scriptID: nil, number: 3)
        take.duration = 10
        let takes = TakeLibraryService(repository: FakeTakeRepository(takes: [take]))
        takes.load()
        let library = ScriptLibraryService(repository: FakeScriptRepository(scripts: []))
        library.load()
        let editor = FakeTakeEditor()
        editor.duration = 10
        let player = FakeEditPlayback()
        let viewModel = QuickEditViewModel(
            take: takes.takes[0], takes: takes, library: library, editing: editor, drafts: FakeDraftStore(), toast: ToastService(),
            player: player, mediaImporter: FakeMediaImporter(), recorder: FakeVoiceRecorder(), styles: FakeTextStyleStore()
        )
        await viewModel.prepare()
        let words = Self.said.enumerated().map { index, text in
            CaptionWord(text: text, start: Double(index) * 0.5, end: Double(index) * 0.5 + 0.35)
        }
        viewModel.edit.captionTranscript = CaptionTranscript(words: words, languageCode: "en")
        viewModel.change { $0.captions = [CaptionCue(words: words)] }
        return (viewModel, player)
    }

    @Test func aCutKeepsThePauseBeforeAndDropsTheOneAfter() {
        let words = Self.said.enumerated().map { index, text in
            CaptionWord(text: text, start: Double(index) * 0.5, end: Double(index) * 0.5 + 0.35)
        }
        let listed = words.enumerated().map { index, word in
            TranscriptWord(
                id: "\(index)", text: word.text, sourceID: nil, span: TimeSpan(start: word.start, end: word.end), index: index,
                segmentID: nil, editedStart: word.start
            )
        }
        // "I want to": from just before "I" (1.0) to just before "show" (2.5).
        let cut = TranscriptEditing.cut(from: listed[2], to: listed[4], transcript: words, recordingLength: 10)
        #expect(abs(cut.start - 0.95) < 0.000_1)
        #expect(abs(cut.end - 2.45) < 0.000_1)
        // Never into the word before: "today" ends at 0.85.
        #expect(cut.start >= 0.85)
        // The last words: a short tail kept.
        let end = TranscriptEditing.cut(from: listed[8], to: listed[8], transcript: words, recordingLength: 10)
        #expect(abs(end.end - (4.35 + TranscriptEditing.tail)) < 0.000_1)
    }

    @Test func cuttingWordsCutsTheVideoAndTheirCaptionsInOneStep() async throws {
        let (viewModel, player) = await makeViewModel()
        #expect(viewModel.hasTranscript)
        #expect(viewModel.transcriptWords.map(\.text) == Self.said)
        viewModel.tapTranscriptWord(at: 2)
        #expect(player.currentTime == 1)
        viewModel.tapTranscriptWord(at: 4)
        #expect(viewModel.selectedTranscriptWords.map(\.text) == ["I", "want", "to"])
        let steps = viewModel.history.past.count
        viewModel.cutSelectedWords()
        #expect(viewModel.history.past.count == steps + 1)
        #expect(abs(viewModel.edit.editedDuration - 8.5) < 0.000_1)
        #expect(viewModel.transcriptSelection == nil)
        // Listed crossed out, and gone from the caption.
        #expect(viewModel.transcriptWords.filter(\.isRemoved).map(\.text) == ["I", "want", "to"])
        // The line shows on both sides of the cut, without the cut words.
        #expect(viewModel.edit.editedCaptions.map(\.text).joined(separator: " ") == "So today show you three habits")
        // Put back.
        viewModel.tapTranscriptWord(at: 2)
        viewModel.tapTranscriptWord(at: 4)
        viewModel.restoreSelectedWords()
        #expect(abs(viewModel.edit.editedDuration - 10) < 0.000_1)
        viewModel.undo()
        #expect(abs(viewModel.edit.editedDuration - 8.5) < 0.000_1)
    }

    @Test func fixingCaptionTextNeverCuts() async throws {
        let (viewModel, _) = await makeViewModel()
        viewModel.sheet = .transcript
        viewModel.tapTranscriptWord(at: 7)
        let duration = viewModel.edit.editedDuration
        viewModel.fixCaptionOfSelectedWords()
        #expect(viewModel.edit.editedDuration == duration)
        #expect(viewModel.sheet == nil)
        #expect(viewModel.panel == .captions)
        #expect(viewModel.editingCaptionID == viewModel.edit.captions.first?.id)
    }

    @Test func wordsOfAnotherRecordingAreCutInThatRecording() async throws {
        let (viewModel, _) = await makeViewModel()
        let other = UUID()
        var source = ClipSource(fileName: "other.mov", duration: 4, title: "Take 2")
        source.id = other
        var next = viewModel.edit
        next.sources = [source]
        next.timeline.insertClip(source: other, duration: 4)
        var theirs = CaptionTranscript(words: [CaptionWord(text: "Hello", start: 1, end: 1.4), CaptionWord(text: "there", start: 1.6, end: 2)],
                                       languageCode: "en")
        theirs.sourceID = other
        next.sourceTranscripts = [theirs]
        viewModel.commit(EditSnapshot(next))
        viewModel.edit.sourceTranscripts = [theirs]
        let words = viewModel.transcriptWords
        let hello = try #require(words.firstIndex { $0.text == "Hello" })
        viewModel.tapTranscriptWord(at: hello)
        viewModel.cutSelectedWords()
        let pieces = viewModel.edit.timeline.segments.filter { $0.sourceID == other }
        #expect(pieces.allSatisfy { !$0.span.overlaps(TimeSpan(start: 1.05, end: 1.5)) })
        // The take is untouched.
        #expect(viewModel.edit.timeline.segments.filter { $0.sourceID == nil }.map(\.span) == [TimeSpan(start: 0, end: 10)])
    }
}

/// Video templates: captions, texts and motion in one undo step; the words, the lines and the graphics stay; a hook with the
/// script's title when there was no text.
@MainActor
@Suite("Quick edit video templates")
struct QuickEditVideoTemplateTests {
    @Test func aTemplateRestylesEverythingInOneStepAndKeepsTheWords() async throws {
        let script = TestData.script(text: "Okay, real talk.")
        var take = TestData.take(scriptID: script.id, number: 3)
        take.duration = 20
        let takes = TakeLibraryService(repository: FakeTakeRepository(takes: [take]))
        takes.load()
        let library = ScriptLibraryService(repository: FakeScriptRepository(scripts: [script]))
        library.load()
        let editor = FakeTakeEditor()
        editor.duration = 20
        let viewModel = QuickEditViewModel(
            take: takes.takes[0], takes: takes, library: library, editing: editor, drafts: FakeDraftStore(), toast: ToastService(),
            player: FakeEditPlayback(), mediaImporter: FakeMediaImporter(), recorder: FakeVoiceRecorder(), styles: FakeTextStyleStore()
        )
        await viewModel.prepare()
        viewModel.change { $0.captions = [CaptionCue(text: "Real talk", start: 1, end: 2)] }
        viewModel.addGraphic(.arrow)
        let before = viewModel.edit
        let steps = viewModel.history.past.count
        viewModel.applyVideoTemplate(.boldHook)
        #expect(viewModel.history.past.count == steps + 1)
        #expect(viewModel.edit.captionCollection?.theme == .impact)
        #expect(viewModel.edit.captionAnimation == .highlight)
        #expect(viewModel.edit.captions == before.captions)
        // A hook with the title opens the video; the arrow is untouched.
        let hook = try #require(viewModel.edit.texts.first { $0.graphic == nil })
        #expect(hook.role == .hook)
        #expect(!hook.text.isEmpty)
        #expect(hook.animation?.preset == .pop)
        #expect(viewModel.edit.texts.first { $0.graphic != nil } == before.texts.first)
        // Another template restyles the hook, keeping its words.
        viewModel.applyVideoTemplate(.story)
        #expect(viewModel.edit.texts.filter { $0.graphic == nil }.count == 1)
        #expect(viewModel.edit.texts.first { $0.graphic == nil }?.text == hook.text)
        #expect(viewModel.edit.texts.first { $0.graphic == nil }?.preset == .editorial)
        viewModel.undo()
        viewModel.undo()
        #expect(viewModel.edit.texts == before.texts)
        #expect(viewModel.edit.captionCollection == before.captionCollection)
    }
}

/// Freeze frame: the clip is split at the playhead and the frame plays there as a clip of its own, with the clip's look, in
/// one undo step; a failure leaves the edit as it was.
@MainActor
@Suite("Quick edit freeze frame")
struct QuickEditFreezeFrameTests {
    private func makeViewModel(editor: FakeTakeEditor) -> QuickEditViewModel {
        let script = TestData.script(text: "Okay, real talk.")
        var take = TestData.take(scriptID: script.id, number: 3)
        take.duration = 10
        let takes = TakeLibraryService(repository: FakeTakeRepository(takes: [take]))
        takes.load()
        let library = ScriptLibraryService(repository: FakeScriptRepository(scripts: [script]))
        library.load()
        editor.duration = 10
        return QuickEditViewModel(
            take: takes.takes[0], takes: takes, library: library, editing: editor, drafts: FakeDraftStore(), toast: ToastService(),
            player: FakeEditPlayback(), mediaImporter: FakeMediaImporter(), recorder: FakeVoiceRecorder(), styles: FakeTextStyleStore()
        )
    }

    @Test func theFrameUnderThePlayheadHoldsAsAClip() async throws {
        let editor = FakeTakeEditor()
        let viewModel = makeViewModel(editor: editor)
        await viewModel.prepare()
        viewModel.change { snapshot in
            var segment = snapshot.timeline.segments[0]
            var look = ClipLook()
            look.exposure = 0.3
            segment.look = look
            snapshot.timeline.replaceSegment(segment)
        }
        viewModel.player.seek(to: 4)
        let before = viewModel.edit
        await viewModel.freezeFrame()
        let timeline = viewModel.edit.timeline
        #expect(timeline.segments.count == 3)
        #expect(abs((editor.stillClips.first?.time ?? 0) - 4) < 0.001)
        let frozen = timeline.segments[1]
        #expect(frozen.sourceID == viewModel.edit.sources.first?.id)
        #expect(viewModel.edit.sources.first?.fileName == "still-1.mov")
        #expect(abs(frozen.duration - QuickEditViewModel.freezeLength) < 0.001)
        #expect(frozen.look == before.timeline.segments[0].look)
        #expect(abs(timeline.editedDuration - (10 + QuickEditViewModel.freezeLength)) < 0.001)
        #expect(abs(timeline.segments[2].sourceStart - 4) < 0.001)
        viewModel.undo()
        #expect(viewModel.edit.timeline == before.timeline)
    }

    @Test func aFrameThatCantBeReadChangesNothing() async {
        let editor = FakeTakeEditor()
        editor.stillClipFails = true
        let viewModel = makeViewModel(editor: editor)
        await viewModel.prepare()
        let before = viewModel.edit
        await viewModel.freezeFrame()
        #expect(viewModel.edit == before)
    }
}
