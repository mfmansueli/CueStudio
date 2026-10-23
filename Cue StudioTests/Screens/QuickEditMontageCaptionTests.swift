//
//  QuickEditMontageCaptionTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

/// Caption lines in a montage keep their recording: "Join next" goes by what plays next and never joins another recording's
/// line or an earlier moment, nudging a line's edge stays on its clip, a dragged line stays on a clip of its recording, and
/// Split works on a copied clip too.
@MainActor
@Suite("Quick edit captions in a montage")
struct QuickEditMontageCaptionTests {
    private let other = UUID()

    /// The take (10 s) and another recording (6 s) after it, with lines in both.
    private func makeViewModel() async -> (QuickEditViewModel, FakeEditPlayback, ToastService) {
        var take = TestData.take(scriptID: nil, number: 3)
        take.duration = 10
        var edit = TakeEdit(sourceDuration: 10, aspect: take.aspect)
        var source = ClipSource(fileName: "other.mov", duration: 6, title: "Take 2")
        source.id = other
        edit.sources = [source]
        edit.timeline.insertClip(source: other, duration: 6)
        var first = CaptionCue(text: "Hello there", start: 7, end: 9)
        first.id = UUID()
        var second = CaptionCue(text: "my friends", start: 9.2, end: 9.9)
        second.id = UUID()
        var theirs = CaptionCue(text: "Over here", start: 0.5, end: 2)
        theirs.sourceID = other
        edit.captions = [first, second, theirs]
        edit.showsCaptions = true
        take.edit = edit
        let takes = TakeLibraryService(repository: FakeTakeRepository(takes: [take]))
        takes.load()
        let library = ScriptLibraryService(repository: FakeScriptRepository(scripts: []))
        library.load()
        let editor = FakeTakeEditor()
        editor.duration = 10
        let player = FakeEditPlayback()
        let toast = ToastService()
        let viewModel = QuickEditViewModel(
            take: takes.takes[0], takes: takes, library: library, editing: editor,
            drafts: FakeDraftStore(), toast: toast, player: player,
            mediaImporter: FakeMediaImporter(), recorder: FakeVoiceRecorder(), styles: FakeTextStyleStore()
        )
        await viewModel.prepare()
        return (viewModel, player, toast)
    }

    private func line(_ text: String, in viewModel: QuickEditViewModel) -> CaptionCue? {
        viewModel.edit.captions.first { $0.text == text }
    }

    @Test func joinNextJoinsTheNextThingSaidInTheSameRecording() async throws {
        let (viewModel, _, _) = await makeViewModel()
        let first = try #require(line("Hello there", in: viewModel))
        viewModel.captions.joinCaption(first.id)
        let joined = try #require(line("Hello there my friends", in: viewModel))
        #expect(joined.start == 7 && joined.end == 9.9)
        #expect(joined.sourceID == nil)
    }

    @Test func joinNextNeverJoinsAnotherRecordingsLine() async throws {
        let (viewModel, _, toast) = await makeViewModel()
        let second = try #require(line("my friends", in: viewModel))
        // What plays after "my friends" is the other take's "Over here".
        #expect(CaptionJoin.next(after: second.id, in: viewModel.edit) == .otherRecording)
        let before = viewModel.edit.captions
        viewModel.captions.joinCaption(second.id)
        #expect(viewModel.edit.captions == before)
        #expect(toast.message == "The next line is from another clip")
        // The other take's line is said at 0.5 s of its recording but plays last: before, it was joined with the take's
        // "Hello there" (7 s of another recording), mixing their times.
        let theirs = try #require(line("Over here", in: viewModel))
        #expect(CaptionJoin.next(after: theirs.id, in: viewModel.edit) == .lastLine)
        viewModel.captions.joinCaption(theirs.id)
        #expect(viewModel.edit.captions == before)
    }

    @Test func joinNextNeverJoinsAnEarlierMoment() async throws {
        let (viewModel, _, _) = await makeViewModel()
        // The take cut at 8.9 s and its end put first: "my friends" plays, then "Hello there".
        var timeline = viewModel.edit.timeline
        timeline.split(atEdited: 9.1)
        timeline.moveSegment(from: 1, to: 0)
        viewModel.commit(timeline)
        let second = try #require(line("my friends", in: viewModel))
        #expect(CaptionJoin.next(after: second.id, in: viewModel.edit) == .earlierInTheRecording)
        let before = viewModel.edit.captions
        viewModel.captions.joinCaption(second.id)
        #expect(viewModel.edit.captions == before)
    }

    @Test func aNudgedEdgeStaysOnItsOwnClip() async throws {
        let (viewModel, _, _) = await makeViewModel()
        let second = try #require(line("my friends", in: viewModel))
        // Its end is 0.1 s before the take ends; pushing it on stops at the end of the take, never in the other recording.
        for _ in 0..<5 { viewModel.captions.nudgeCaption(second.id, edge: .end, by: 0.1) }
        let nudged = try #require(viewModel.edit.captions.first { $0.id == second.id })
        #expect(nudged.end <= 10.000_1)
        #expect(nudged.end > 9.9)
        #expect(nudged.sourceID == nil)
    }

    @Test func aDraggedLineStaysOnAClipOfItsRecording() async throws {
        let (viewModel, _, toast) = await makeViewModel()
        let theirs = try #require(line("Over here", in: viewModel))
        let bar = try #require(viewModel.captionBars.first { $0.title == "Over here" })
        // Onto the take, at 3 s: refused.
        viewModel.moveBar(bar, toStart: 3)
        #expect(viewModel.edit.captions.first { $0.id == theirs.id }?.start == 0.5)
        #expect(toast.message == "A line stays on its own clip")
        // Along its own clip: moved, in that recording's seconds.
        viewModel.moveBar(bar, toStart: 12)
        #expect(abs((viewModel.edit.captions.first { $0.id == theirs.id }?.start ?? 0) - 2) < 0.001)
    }

    @Test func splitWorksOnACopiedClip() async throws {
        let (viewModel, player, _) = await makeViewModel()
        viewModel.clips.duplicateSection(viewModel.edit.timeline.segments[1].id)
        let theirs = try #require(line("Over here", in: viewModel))
        // In the copy (16–22 s), 1.2 s in is "Over | here".
        player.currentTime = 17.25
        viewModel.captions.splitCaptionAtPlayhead(theirs.id)
        #expect(viewModel.edit.captions.filter { $0.sourceID == other }.count == 2)
    }
}
