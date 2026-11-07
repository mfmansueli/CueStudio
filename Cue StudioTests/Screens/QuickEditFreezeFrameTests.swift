//
//  QuickEditFreezeFrameTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

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
        await viewModel.clips.freezeFrame()
        let timeline = viewModel.edit.timeline
        #expect(timeline.segments.count == 3)
        #expect(abs((editor.stillClips.first?.time ?? 0) - 4) < 0.001)
        let frozen = timeline.segments[1]
        #expect(frozen.sourceID == viewModel.edit.sources.first?.id)
        #expect(viewModel.edit.sources.first?.fileName == "still-1.mov")
        #expect(abs(frozen.duration - ClipsViewModel.freezeLength) < 0.001)
        #expect(frozen.look == before.timeline.segments[0].look)
        #expect(abs(timeline.editedDuration - (10 + ClipsViewModel.freezeLength)) < 0.001)
        #expect(abs(timeline.segments[2].sourceStart - 4) < 0.001)
        viewModel.undo()
        #expect(viewModel.edit.timeline == before.timeline)
    }

    /// The cuts changed while the frame was being made: nothing is added or taken away, and the creator is told.
    @Test func aFrameFreezesNothingWhenTheVideoChangedMeanwhile() async throws {
        let editor = FakeTakeEditor()
        let viewModel = makeViewModel(editor: editor)
        await viewModel.prepare()
        viewModel.player.seek(to: 4)
        var changed: TakeEdit?
        editor.whileFreezing = {
            var timeline = viewModel.edit.timeline
            timeline.split(atEdited: 7)
            viewModel.commit(timeline)
            changed = viewModel.edit
        }
        await viewModel.clips.freezeFrame()
        let after = try #require(changed)
        #expect(editor.stillClips.count == 1)
        #expect(viewModel.edit == after)
        #expect(viewModel.edit.timeline.segments.count == 2)
        #expect(viewModel.edit.sources.isEmpty)
        #expect(!viewModel.isImportingMedia)
        #expect(viewModel.toast.message == "The video changed meanwhile · Freeze the frame again")
        // Only the creator's own split is undone.
        viewModel.undo()
        #expect(viewModel.edit.timeline.segments.count == 1)
    }

    /// A clip picked with the playhead on another: Freeze frame says so and freezes nothing, as Split does.
    @Test func aFrameFreezesOnlyOnThePickedClip() async {
        let editor = FakeTakeEditor()
        let viewModel = makeViewModel(editor: editor)
        await viewModel.prepare()
        var timeline = viewModel.edit.timeline
        timeline.split(atEdited: 5)
        viewModel.commit(timeline)
        viewModel.selection = .clip(viewModel.edit.timeline.segments[0].id)
        viewModel.player.seek(to: 7)
        let before = viewModel.edit
        await viewModel.clips.freezeFrame()
        #expect(editor.stillClips.isEmpty)
        #expect(viewModel.edit == before)
        #expect(viewModel.toast.message == "Move playhead onto the clip")
    }

    /// Duplicate picks the copy with the playhead on it: Freeze frame, next, holds the copy's first frame.
    @Test func aDuplicatedClipFreezesRightAway() async {
        let editor = FakeTakeEditor()
        let viewModel = makeViewModel(editor: editor)
        await viewModel.prepare()
        var timeline = viewModel.edit.timeline
        timeline.split(atEdited: 5)
        viewModel.commit(timeline)
        viewModel.player.seek(to: 2)
        viewModel.clips.duplicateClip(viewModel.edit.timeline.segments[0].id)
        let copy = viewModel.edit.timeline.segments[1]
        #expect(viewModel.selection == .clip(copy.id))
        #expect(abs(viewModel.player.currentTime - 5) < 0.001)
        await viewModel.clips.freezeFrame()
        #expect(editor.stillClips.count == 1)
        #expect(abs((editor.stillClips.first?.time ?? -1) - copy.sourceStart) < 0.001)
    }

    @Test func aFrameThatCantBeReadChangesNothing() async {
        let editor = FakeTakeEditor()
        editor.stillClipFails = true
        let viewModel = makeViewModel(editor: editor)
        await viewModel.prepare()
        let before = viewModel.edit
        await viewModel.clips.freezeFrame()
        #expect(viewModel.edit == before)
    }
}
