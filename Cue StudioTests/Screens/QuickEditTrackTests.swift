//
//  QuickEditTrackTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

/// Track in the editor: a text put on a moving square follows it as keyframes, in one undo step.
@MainActor
@Suite("Quick edit track", .serialized)
struct QuickEditTrackTests {
    @Test func aTextOnTheSquareFollowsIt() async throws {
        let footage = try await MovingFootage.make(seconds: 3, width: 360, height: 640, motion: .init(square: ObjectTrackerTests.path, squareSide: 70))
        defer { try? FileManager.default.removeItem(at: footage) }
        var take = TestData.take(scriptID: nil)
        take.duration = 3
        take.fileName = footage.lastPathComponent
        let takes = TakeLibraryService(repository: FakeTakeRepository(takes: [take]))
        takes.load()
        let library = ScriptLibraryService(repository: FakeScriptRepository(scripts: []))
        library.load()
        let player = FakeEditPlayback()
        let editor = FakeTakeEditor()
        editor.duration = 3
        let viewModel = QuickEditViewModel(
            take: takes.takes[0], takes: takes, library: library, editing: editor, drafts: FakeDraftStore(), toast: ToastService(),
            player: player, mediaImporter: FakeMediaImporter(), recorder: FakeVoiceRecorder(), styles: FakeTextStyleStore(),
            coverPictures: FakeCoverPictures()
        )
        await viewModel.prepare()
        player.seek(to: 0.5)
        viewModel.addText(.title)
        let id = try #require(viewModel.selectedTextID)
        // On the square at 0.5 s (frame 15).
        let square = ObjectTrackerTests.path(15)
        viewModel.moveText(id, to: OverlayPoint(x: square.x / 360, y: square.y / 640))
        let steps = viewModel.history.past.count
        viewModel.perform(.trackItem)
        #expect(viewModel.isTracking)
        await Wait.until(timeout: .seconds(120)) { !viewModel.isTracking }
        let keyframes = viewModel.edit.texts.first { $0.id == id }?.keyframes ?? []
        #expect(keyframes.count >= 2 && keyframes.count <= 30, "\(keyframes.count) keyframes")
        #expect(viewModel.history.past.count == steps + 1)
        // At 2.5 s (frame 75) the text is on the square.
        player.seek(to: 2.5)
        let center = viewModel.motionState(of: .text(id)).center
        let truth = ObjectTrackerTests.path(75)
        #expect(abs(center.x - truth.x / 360) < 0.04 && abs(center.y - truth.y / 640) < 0.03, "\(center) vs \(truth)")
        viewModel.undo()
        #expect(viewModel.edit.texts.first { $0.id == id }?.keyframes.isEmpty == true)
    }
}
