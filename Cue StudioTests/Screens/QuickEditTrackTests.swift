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
    private struct Scenario {
        let viewModel: QuickEditViewModel
        let player: FakeEditPlayback
        let toast: ToastService
        let footage: URL
        let textID: UUID
    }

    /// A take of a moving square, with a title on the square at 0.5 s (frame 15).
    private func makeScenario() async throws -> Scenario {
        let footage = try await MovingFootage.make(seconds: 3, width: 360, height: 640, motion: .init(square: ObjectTrackerTests.path, squareSide: 70))
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
        let toast = ToastService()
        let viewModel = QuickEditViewModel(
            take: takes.takes[0], takes: takes, library: library, editing: editor, drafts: FakeDraftStore(), toast: toast,
            player: player, mediaImporter: FakeMediaImporter(), recorder: FakeVoiceRecorder(), styles: FakeTextStyleStore(),
            coverPictures: FakeCoverPictures()
        )
        await viewModel.prepare()
        player.seek(to: 0.5)
        viewModel.overlays.addText(.title)
        let id = try #require(viewModel.selectedTextID)
        let square = ObjectTrackerTests.path(15)
        viewModel.overlays.moveText(id, to: OverlayPoint(x: square.x / 360, y: square.y / 640))
        return Scenario(viewModel: viewModel, player: player, toast: toast, footage: footage, textID: id)
    }

    @Test func aTextOnTheSquareFollowsIt() async throws {
        let scenario = try await makeScenario()
        defer { try? FileManager.default.removeItem(at: scenario.footage) }
        let viewModel = scenario.viewModel, player = scenario.player, id = scenario.textID
        let steps = viewModel.document.history.past.count
        viewModel.perform(.trackItem)
        #expect(viewModel.overlays.isTracking)
        await Wait.until(timeout: .seconds(120)) { !viewModel.overlays.isTracking }
        let keyframes = viewModel.edit.texts.first { $0.id == id }?.keyframes ?? []
        #expect(keyframes.count >= 2 && keyframes.count <= 30, "\(keyframes.count) keyframes")
        #expect(viewModel.document.history.past.count == steps + 1)
        // At 2.5 s (frame 75) the text is on the square.
        player.seek(to: 2.5)
        let center = viewModel.overlays.motionState(of: .text(id)).center
        let truth = ObjectTrackerTests.path(75)
        #expect(abs(center.x - truth.x / 360) < 0.04 && abs(center.y - truth.y / 640) < 0.03, "\(center) vs \(truth)")
        viewModel.undo()
        #expect(viewModel.edit.texts.first { $0.id == id }?.keyframes.isEmpty == true)
    }

    @Test func aCancelledOrOutdatedRunLeavesNothingBehind() async throws {
        let scenario = try await makeScenario()
        defer { try? FileManager.default.removeItem(at: scenario.footage) }
        let viewModel = scenario.viewModel, id = scenario.textID
        let steps = viewModel.document.history.past.count
        // Cancelled, then again at once: only the second run lands, in one step.
        viewModel.perform(.trackItem)
        viewModel.overlays.cancelTracking()
        viewModel.perform(.trackItem)
        await Wait.until(timeout: .seconds(120)) { !viewModel.overlays.isTracking }
        #expect(viewModel.document.history.past.count == steps + 1)
        #expect((viewModel.edit.texts.first { $0.id == id }?.keyframes.count ?? 0) >= 2)
        viewModel.undo()
        // The video changed while it ran: the path, measured on what it was, is dropped.
        viewModel.perform(.trackItem)
        scenario.player.seek(to: 2)
        viewModel.splitClip()
        await Wait.until(timeout: .seconds(120)) { !viewModel.overlays.isTracking }
        #expect(viewModel.edit.texts.first { $0.id == id }?.keyframes.isEmpty == true)
        #expect(scenario.toast.message == "The video changed meanwhile · Track it again")
    }
}
