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
