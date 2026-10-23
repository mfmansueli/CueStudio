//
//  QuickEditAccessibilityTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

/// What VoiceOver does in the editor where a finger drags: the playhead jumps from cut to cut, and a text or a photo moves a
/// step at a time and grows or shrinks, each an undo step.
@MainActor
@Suite("Quick edit with VoiceOver")
struct QuickEditAccessibilityTests {
    private func makeViewModel() async -> (QuickEditViewModel, FakeEditPlayback) {
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
        return (viewModel, player)
    }

    @Test func thePlayheadJumpsFromCutToCut() async {
        let (viewModel, player) = await makeViewModel()
        player.seek(to: 6)
        viewModel.clips.selectClipAtPlayhead()
        viewModel.clips.splitClip()
        player.seek(to: 12)
        viewModel.clips.selectClipAtPlayhead()
        viewModel.clips.splitClip()
        player.seek(to: 2)
        viewModel.jumpToCut(forward: true)
        #expect(abs(player.currentTime - 6) < 0.05)
        viewModel.jumpToCut(forward: true)
        #expect(abs(player.currentTime - 12) < 0.05)
        viewModel.jumpToCut(forward: true)
        #expect(abs(player.currentTime - 20) < 0.05)
        viewModel.jumpToCut(forward: false)
        #expect(abs(player.currentTime - 12) < 0.05)
    }

    @Test func aTextMovesAndGrowsAStepAtATime() async throws {
        let (viewModel, _) = await makeViewModel()
        viewModel.perform(.addText(.title))
        let text = try #require(viewModel.edit.texts.first)
        viewModel.overlays.nudgeOverlay(.text(text.id), x: 0, y: -OverlaysViewModel.overlayStep)
        let moved = try #require(viewModel.edit.texts.first)
        #expect(abs(moved.center.y - (text.center.y - OverlaysViewModel.overlayStep)) < 0.000_1)
        #expect(moved.center.x == text.center.x)
        viewModel.overlays.resizeOverlay(.text(text.id), bigger: true)
        let bigger = try #require(viewModel.edit.texts.first)
        #expect(abs(bigger.size - text.size * OverlaysViewModel.overlayScaleStep) < 0.01)
        viewModel.undo()
        viewModel.undo()
        #expect(viewModel.edit.texts.first?.center == text.center)
        #expect(viewModel.edit.texts.first?.size == text.size)
    }

    @Test func aStepNeverLeavesTheFrame() async throws {
        let (viewModel, _) = await makeViewModel()
        viewModel.perform(.addText(.title))
        let text = try #require(viewModel.edit.texts.first)
        for _ in 0..<40 { viewModel.overlays.nudgeOverlay(.text(text.id), x: -OverlaysViewModel.overlayStep, y: 0) }
        #expect(viewModel.edit.texts.first?.center.x == 0)
    }
}
