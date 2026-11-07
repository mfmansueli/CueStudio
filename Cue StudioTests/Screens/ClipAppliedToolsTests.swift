//
//  ClipAppliedToolsTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

/// Canvas 2 M2: the clip bar marks the tools that changed the picked clip, from the clip itself, so the marks follow another clip
/// picked, Reset clip and Undo; Transition is the cut after the clip.
@Suite("Clip applied tools")
struct ClipAppliedToolsTests {
    @Test func aClipAsFilmedHasNoMarks() {
        let clip = EditSegment(sourceStart: 0, sourceEnd: 4)
        #expect(ClipAppliedTools.ids(of: clip, in: [clip]).isEmpty)
    }

    @Test func eachChangeMarksItsOwnTool() {
        var clip = EditSegment(sourceStart: 0, sourceEnd: 4, speed: 1.5, zoom: .pushIn)
        clip.volume = 0.5
        clip.stabilization = .standard
        clip.isMirrored = true
        var look = ClipLook()
        look.exposure = 0.2
        look.filter = .original
        clip.look = look
        let next = EditSegment(sourceStart: 4, sourceEnd: 8, transitionIn: .dissolve)
        let ids = ClipAppliedTools.ids(of: clip, in: [clip, next])
        #expect(ids == ["speed", "volume", "zoom", "adjust", "filters", "stabilize", "transition"])
        // The cut after the next one is the next clip's own: none there.
        #expect(!ClipAppliedTools.ids(of: next, in: [clip, next, EditSegment(sourceStart: 8, sourceEnd: 9)]).contains("transition"))
    }

    @MainActor
    @Test func theClipBarDrawsTheMarksAndFollowsUndo() async throws {
        var take = TestData.take(scriptID: nil, number: 3)
        take.duration = SampleEdit.duration
        take.edit = SampleEdit.make(aspect: take.aspect)
        let takes = TakeLibraryService(repository: FakeTakeRepository(takes: [take]))
        takes.load()
        let library = ScriptLibraryService(repository: FakeScriptRepository(scripts: []))
        library.load()
        let editor = FakeTakeEditor()
        editor.duration = SampleEdit.duration
        let viewModel = QuickEditViewModel(
            take: takes.takes[0], takes: takes, library: library, editing: editor,
            drafts: FakeDraftStore(), toast: ToastService(), player: FakeEditPlayback(),
            mediaImporter: FakeMediaImporter(), recorder: FakeVoiceRecorder(), styles: FakeTextStyleStore()
        )
        await viewModel.prepare()
        let clip = try #require(viewModel.edit.timeline.segments.first)
        viewModel.pick(.clip(clip.id))
        func speedIsMarked() -> Bool? { viewModel.items(for: .clip(clip.id)).first { $0.id == "speed" }?.isApplied }
        #expect(speedIsMarked() == false)
        viewModel.clips.setClipSpeed(2)
        #expect(speedIsMarked() == true)
        viewModel.undo()
        #expect(speedIsMarked() == false)
    }
}
