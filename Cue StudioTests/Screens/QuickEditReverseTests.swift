//
//  QuickEditReverseTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

/// Reverse in the editor: the clip plays a reversed copy of its stretch, in one undo step, the texts and voice-overs on it stay
/// where they were in the video, reversing it again plays the original, and once more plays the copy already written.
@MainActor
@Suite("Quick edit reverse", .serialized)
struct QuickEditReverseTests {
    @Test func reversesAndPutsBack() async throws {
        let footage = try await TestClip.make(seconds: 4, loudSeconds: [1])
        defer { try? FileManager.default.removeItem(at: footage) }
        var take = TestData.take(scriptID: nil)
        take.duration = 4
        take.fileName = footage.lastPathComponent
        let takes = TakeLibraryService(repository: FakeTakeRepository(takes: [take]))
        takes.load()
        let library = ScriptLibraryService(repository: FakeScriptRepository(scripts: []))
        library.load()
        let player = FakeEditPlayback()
        let editor = FakeTakeEditor()
        editor.duration = 4
        let viewModel = QuickEditViewModel(
            take: takes.takes[0], takes: takes, library: library, editing: editor, drafts: FakeDraftStore(), toast: ToastService(),
            player: player, mediaImporter: FakeMediaImporter(), recorder: FakeVoiceRecorder(), styles: FakeTextStyleStore(),
            coverPictures: FakeCoverPictures()
        )
        await viewModel.prepare()
        // A clip from 1 s to 3 s, a title at 2.2 s on it.
        player.seek(to: 1)
        viewModel.splitClip()
        player.seek(to: 3)
        viewModel.splitClip()
        player.seek(to: 2.2)
        viewModel.addText(.title)
        let textID = try #require(viewModel.selectedTextID)
        let textStart = try #require(viewModel.editedSpan(ofText: textID)).start
        // A voice-over starting at 2.5 s, on the same clip.
        viewModel.change { $0.voiceOvers.append(VoiceOverClip(fileName: "voice.m4a", duration: 0.3, anchor: 2.5)) }
        let voiceStart = try #require(viewModel.edit.voiceOvers.first?.editedSpan(in: viewModel.edit.timeline)).start
        let clip = viewModel.edit.timeline.segments[1]
        viewModel.selection = .clip(clip.id)
        let steps = viewModel.document.history.past.count
        await viewModel.reverseClip()
        let reversed = viewModel.edit.timeline.segments[1]
        let source = try #require(viewModel.edit.sources.first { $0.id == reversed.sourceID })
        defer { EditMediaFiles.remove([source.fileName]) }
        #expect(source.reversal == ClipReversal(sourceID: nil, span: clip.span))
        #expect(abs(reversed.duration - clip.duration) < 0.001)
        #expect(viewModel.document.history.past.count == steps + 1)
        #expect(abs((viewModel.editedSpan(ofText: textID)?.start ?? -1) - textStart) < 0.01)
        #expect(abs((viewModel.edit.voiceOvers.first?.editedSpan(in: viewModel.edit.timeline)?.start ?? -1) - voiceStart) < 0.01)
        // Again: forward, the original stretch of the take.
        await viewModel.reverseClip()
        let back = viewModel.edit.timeline.segments[1]
        #expect(back.sourceID == nil && abs(back.sourceStart - clip.sourceStart) < 0.001 && abs(back.sourceEnd - clip.sourceEnd) < 0.001)
        #expect(abs((viewModel.editedSpan(ofText: textID)?.start ?? -1) - textStart) < 0.01)
        #expect(abs((viewModel.edit.voiceOvers.first?.editedSpan(in: viewModel.edit.timeline)?.start ?? -1) - voiceStart) < 0.01)
        // Once more: the reversed video already written plays again, no new file.
        let sources = viewModel.edit.sources.count
        await viewModel.reverseClip()
        #expect(viewModel.edit.sources.count == sources)
        #expect(viewModel.edit.timeline.segments[1].sourceID == source.id)
        #expect(abs(viewModel.edit.timeline.segments[1].sourceStart - reversed.sourceStart) < 0.001)
        #expect(abs((viewModel.editedSpan(ofText: textID)?.start ?? -1) - textStart) < 0.01)
    }
}
