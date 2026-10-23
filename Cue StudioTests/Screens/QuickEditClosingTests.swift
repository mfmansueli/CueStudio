//
//  QuickEditClosingTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

/// Leaving the editor while a tool is still working: what the work hands back after is dropped, never laid on the edit or
/// the draft, and work started from a tool is cancelled.
@MainActor
@Suite("Quick edit: leaving while a tool works")
struct QuickEditClosingTests {
    private func makeViewModel(editor: FakeTakeEditor, drafts: FakeDraftStore = FakeDraftStore()) async -> QuickEditViewModel {
        var take = TestData.take(scriptID: nil, number: 1)
        take.duration = 20
        let takes = TakeLibraryService(repository: FakeTakeRepository(takes: [take]))
        takes.load()
        let library = ScriptLibraryService(repository: FakeScriptRepository(scripts: []))
        library.load()
        editor.duration = 20
        let viewModel = QuickEditViewModel(
            take: takes.takes[0], takes: takes, library: library, editing: editor,
            drafts: drafts, toast: ToastService(), player: FakeEditPlayback(),
            mediaImporter: FakeMediaImporter(), recorder: FakeVoiceRecorder(), styles: FakeTextStyleStore()
        )
        await viewModel.prepare()
        return viewModel
    }

    @Test func aFrameFrozenAfterLeavingIsDropped() async {
        let editor = FakeTakeEditor()
        let drafts = FakeDraftStore()
        let viewModel = await makeViewModel(editor: editor, drafts: drafts)
        viewModel.player.seek(to: 4)
        editor.whileFreezing = { viewModel.cancel() }
        await viewModel.clips.freezeFrame()
        #expect(editor.stillClips.count == 1)
        #expect(viewModel.isClosed)
        #expect(viewModel.edit.sources.isEmpty)
        #expect(viewModel.edit.timeline.segments.count == 1)
        #expect(drafts.drafts.isEmpty)
    }

    @Test func aSoundPulledOutAfterLeavingIsDropped() async {
        let editor = FakeTakeEditor()
        let viewModel = await makeViewModel(editor: editor)
        viewModel.clips.selectClipAtPlayhead()
        editor.whileExtracting = { viewModel.cancel() }
        await viewModel.audio.extractAudio()
        #expect(editor.extractions.count == 1)
        #expect(viewModel.edit.music.isEmpty)
    }

    @Test func leavingCancelsWorkStartedFromATool() async {
        let viewModel = await makeViewModel(editor: FakeTakeEditor())
        var finished = false
        var wasCancelled = false
        viewModel.startJob {
            try? await Task.sleep(for: .seconds(30))
            wasCancelled = Task.isCancelled
            finished = true
        }
        await Task.yield()
        viewModel.cancel()
        while !finished { await Task.yield() }
        #expect(wasCancelled)
    }

    @Test func nothingStartsOnceClosed() async {
        let viewModel = await makeViewModel(editor: FakeTakeEditor())
        viewModel.cancel()
        var ran = false
        viewModel.startJob { ran = true }
        for _ in 0..<5 { await Task.yield() }
        #expect(!ran)
    }
}

/// A preview that failed builds again: from Try again, and on its own when Cue comes back to the front.
@MainActor
@Suite("Quick edit: a failed preview")
struct QuickEditPreviewRetryTests {
    @Test func tryAgainAndComingBackBuildTheFailedPreview() async {
        var take = TestData.take(scriptID: nil, number: 1)
        take.duration = 20
        let takes = TakeLibraryService(repository: FakeTakeRepository(takes: [take]))
        takes.load()
        let library = ScriptLibraryService(repository: FakeScriptRepository(scripts: []))
        library.load()
        let editor = FakeTakeEditor()
        editor.duration = 20
        let player = FakeEditPlayback()
        let viewModel = QuickEditViewModel(
            take: takes.takes[0], takes: takes, library: library, editing: editor, drafts: FakeDraftStore(), toast: ToastService(),
            player: player, mediaImporter: FakeMediaImporter(), recorder: FakeVoiceRecorder(), styles: FakeTextStyleStore()
        )
        await viewModel.prepare()
        viewModel.becameActive()
        #expect(player.retries == 0)
        player.state = .failed
        viewModel.retryPreview()
        #expect(player.retries == 1)
        player.state = .failed
        viewModel.becameActive()
        #expect(player.retries == 2)
        #expect(viewModel.isReady)
    }
}
