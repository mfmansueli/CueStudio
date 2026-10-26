//
//  QuickEditMaskTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

/// Mask in the editor: on a window or a full-screen photo or video, never on a split screen's support (not on its toolbar, and
/// said why if asked); shapes put on and swapped keeping where the mask is, Invert, a slider as one undo step, the picture
/// reframed under it, keyframes moving it over time, ◐ and Reset.
@MainActor
@Suite("Mask in the editor")
struct QuickEditMaskTests {
    private func makeViewModel() async -> (QuickEditViewModel, FakeEditPlayback, ToastService) {
        var take = TestData.take(scriptID: nil)
        take.duration = 20
        let takes = TakeLibraryService(repository: FakeTakeRepository(takes: [take]))
        takes.load()
        let library = ScriptLibraryService(repository: FakeScriptRepository(scripts: []))
        library.load()
        let player = FakeEditPlayback()
        let toast = ToastService()
        let viewModel = QuickEditViewModel(
            take: takes.takes[0], takes: takes, library: library, editing: FakeTakeEditor(), drafts: FakeDraftStore(), toast: toast,
            player: player, mediaImporter: FakeMediaImporter(), recorder: FakeVoiceRecorder(), styles: FakeTextStyleStore()
        )
        await viewModel.prepare()
        player.seek(to: 2)
        return (viewModel, player, toast)
    }

    private func addWindow(_ viewModel: QuickEditViewModel) async throws -> MediaOverlay {
        viewModel.overlays.addMedia(ImportedMedia(kind: .video, fileName: "v-\(UUID().uuidString).mov", aspect: 16.0 / 9, duration: 6))
        let media = try #require(viewModel.selectedMedia)
        await viewModel.overlays.setMediaLayout(media.id, .window)
        return try #require(viewModel.selectedMedia)
    }

    @Test func aShapeGoesOnAndAnotherKeepsWhereItIs() async throws {
        let (viewModel, _, _) = await makeViewModel()
        _ = try await addWindow(viewModel)
        // A video's own tools on screen: its panel, sound, motion and mask.
        #expect(Array(viewModel.toolbarItems.map(\.id).prefix(4)) == ["editMedia", "mediaVolume", "mediaMotion", "mask"])
        viewModel.perform(.openMask)
        #expect(viewModel.panel == .mask)
        viewModel.overlays.setMaskShape(.circle)
        var mask = try #require(viewModel.selectedMedia?.mask)
        #expect(mask.shape == .circle)
        viewModel.overlays.nudgeMask(x: 0.1, y: 0)
        viewModel.overlays.setMaskShape(.rectangle)
        mask = try #require(viewModel.selectedMedia?.mask)
        #expect(mask.shape == .rectangle)
        #expect(abs(mask.placement.center.x - 0.6) < 0.000_1)
        viewModel.overlays.setMaskInverted(true)
        #expect(viewModel.selectedMedia?.mask?.inverted == true)
        viewModel.overlays.setMaskShape(nil)
        #expect(viewModel.selectedMedia?.mask == nil)
        viewModel.undo()
        #expect(viewModel.selectedMedia?.mask?.inverted == true)
    }

    @Test func aSliderIsOneUndoStep() async throws {
        let (viewModel, _, _) = await makeViewModel()
        _ = try await addWindow(viewModel)
        viewModel.overlays.setMaskShape(.rectangle)
        let steps = viewModel.document.history.past.count
        viewModel.beginChange()
        for value in stride(from: 0.1, through: 0.9, by: 0.1) { viewModel.overlays.setMaskFeather(value) }
        viewModel.endChange()
        #expect(viewModel.document.history.past.count == steps + 1)
        #expect(abs((viewModel.selectedMedia?.mask?.placement.feather ?? 0) - 0.9) < 0.000_1)
    }

    @Test func aSplitScreensSupportHasNoMask() async throws {
        let (viewModel, _, toast) = await makeViewModel()
        await viewModel.overlays.add([MediaPick(ImportedMedia(kind: .photo, fileName: "p-\(UUID().uuidString).jpg", aspect: 1, duration: nil))], as: .split)
        #expect(viewModel.selectedMedia?.layout == .split)
        #expect(!viewModel.toolbarItems.map(\.id).contains("mask"))
        viewModel.perform(.openMask)
        #expect(viewModel.panel != .mask)
        #expect(toast.message?.contains("split-screen area already has its shape") == true)
    }

    @Test func withKeyframesTheMaskMovesOverTime() async throws {
        let (viewModel, player, _) = await makeViewModel()
        let media = try await addWindow(viewModel)
        viewModel.overlays.setMaskShape(.circle)
        // Keyframes at 2 s and 4 s (the media starts at 2 s).
        viewModel.overlays.toggleKeyframe()
        player.seek(to: 4)
        viewModel.overlays.toggleKeyframe()
        // The mask small at 2 s, big at 4 s.
        player.seek(to: 2)
        viewModel.overlays.updateMaskPlacement { $0.width = 0.2 }
        player.seek(to: 4)
        viewModel.overlays.updateMaskPlacement { $0.width = 0.8 }
        let keyframes = try #require(viewModel.edit.media.first { $0.id == media.id }?.keyframes)
        #expect(keyframes.compactMap(\.mask).count == 2)
        player.seek(to: 3)
        let halfway = try #require(viewModel.selectedMedia.flatMap { viewModel.overlays.maskPlacementAtPlayhead(of: $0) })
        #expect(halfway.width > 0.3 && halfway.width < 0.7, "\(halfway.width)")
    }

    @Test func thePictureIsReframedUnderTheMaskAndResetPutsItBack() async throws {
        let (viewModel, _, _) = await makeViewModel()
        _ = try await addWindow(viewModel)
        viewModel.overlays.setMaskShape(.circle)
        viewModel.overlays.maskDragTarget = .picture
        viewModel.overlays.zoomMaskedPicture(by: 2)
        viewModel.overlays.panMaskedPicture(by: CGSize(width: 40, height: 0), placeSize: CGSize(width: 300, height: 170))
        let framing = try #require(viewModel.selectedMedia?.pictureFraming)
        #expect(framing.zoom == 2)
        #expect(framing.center.x < 0.5, "the picture followed the finger right: its left part is in the middle")
        #expect(viewModel.overlays.maskIsAdjusted)
        viewModel.overlays.resetMask()
        #expect(viewModel.selectedMedia?.pictureFraming == nil)
        #expect(!viewModel.overlays.maskIsAdjusted)
    }

    @Test func compareShowsItWhole() async throws {
        let (viewModel, player, _) = await makeViewModel()
        _ = try await addWindow(viewModel)
        viewModel.perform(.openMask)
        viewModel.overlays.setMaskShape(.circle)
        viewModel.overlays.maskCompare.show(true)
        #expect(viewModel.playedEdit.media.first?.mask == nil)
        #expect(player.shown.last?.media.first?.mask == nil)
        viewModel.panel = nil
        #expect(!viewModel.overlays.comparesWithoutMask)
        #expect(viewModel.playedEdit.media.first?.mask != nil)
    }
}
