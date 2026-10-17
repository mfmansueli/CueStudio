//
//  QuickEditOverlayPickingTests.swift
//  Cue StudioTests
//

import CoreGraphics
import Foundation
import Testing
@testable import Cue_Studio

/// Photos and videos that overlap on the preview: handles in the order the video stacks them, a tap on the one on top, the
/// next tap where they overlap on the one under it, and while one is dragged the video leaves it out so it never shows twice.
@MainActor
@Suite("Quick edit overlay picking")
struct QuickEditOverlayPickingTests {
    private let size = CGSize(width: 300, height: 600)

    private func makeViewModel() async -> (QuickEditViewModel, FakeEditPlayback) {
        var take = TestData.take(scriptID: nil, number: 3)
        take.duration = 20
        let takes = TakeLibraryService(repository: FakeTakeRepository(takes: [take]))
        takes.load()
        let library = ScriptLibraryService(repository: FakeScriptRepository(scripts: []))
        library.load()
        let editor = FakeTakeEditor()
        editor.duration = 20
        let player = FakeEditPlayback()
        let viewModel = QuickEditViewModel(
            take: takes.takes[0], takes: takes, library: library, editing: editor,
            drafts: FakeDraftStore(), toast: ToastService(), player: player,
            mediaImporter: FakeMediaImporter(), recorder: FakeVoiceRecorder(), styles: FakeTextStyleStore()
        )
        await viewModel.prepare()
        return (viewModel, player)
    }

    /// Three windows at 2 s: A and B over the middle, B on top of A, C apart at the top.
    private func addThree(to viewModel: QuickEditViewModel, player: FakeEditPlayback) -> [UUID] {
        player.currentTime = 2
        var ids: [UUID] = []
        for (x, y) in [(0.5, 0.5), (0.55, 0.52), (0.5, 0.12)] {
            viewModel.addMedia(ImportedMedia(kind: .photo, fileName: "p-\(UUID().uuidString).jpg", aspect: 1, duration: nil))
            let id = viewModel.edit.media.last!.id
            viewModel.updateMedia(id) { media in
                media.layout = .window
                media.width = 0.4
                media.center = OverlayPoint(x: x, y: y)
            }
            ids.append(id)
        }
        player.currentTime = 2
        viewModel.selection = nil
        return ids
    }

    @Test func everyWindowShowingHasItsHandleInStackingOrder() async {
        let (viewModel, player) = await makeViewModel()
        let ids = addThree(to: viewModel, player: player)
        #expect(viewModel.visibleMediaStack.map(\.id) == ids)
        viewModel.restack(ids[0], up: true)
        #expect(viewModel.visibleMediaStack.map(\.id) == [ids[1], ids[0], ids[2]])
    }

    @Test func aTapPicksTheTopOneThenTheOneUnderIt() async {
        let (viewModel, player) = await makeViewModel()
        let ids = addThree(to: viewModel, player: player)
        // Where A and B overlap.
        let overlap = CGPoint(x: 0.53 * size.width, y: 0.51 * size.height)
        #expect(viewModel.mediaHits(at: overlap, in: size) == [ids[1], ids[0]])
        viewModel.tapMedia(at: overlap, in: size)
        #expect(viewModel.selection == .media(ids[1]))
        viewModel.tapMedia(at: overlap, in: size)
        #expect(viewModel.selection == .media(ids[0]))
        viewModel.tapMedia(at: overlap, in: size)
        #expect(viewModel.selection == .media(ids[1]))
        // A window alone under the finger, already picked: its panel opens.
        let alone = CGPoint(x: 0.5 * size.width, y: 0.12 * size.height)
        viewModel.tapMedia(at: alone, in: size)
        #expect(viewModel.selection == .media(ids[2]))
        viewModel.tapMedia(at: alone, in: size)
        #expect(viewModel.panel == .media)
    }

    @Test func aDraggedTextOrPhotoIsLeftOutOfTheVideoUntilItLands() async {
        let (viewModel, player) = await makeViewModel()
        let ids = addThree(to: viewModel, player: player)
        viewModel.addText(.title)
        let text = viewModel.edit.texts[0].id
        viewModel.beginOverlayDrag(.text(text))
        #expect(player.shown.last?.texts.isEmpty == true)
        viewModel.moveText(text, to: OverlayPoint(x: 0.4, y: 0.4))
        viewModel.endOverlayDrag()
        #expect(player.shown.last?.texts.first?.center == OverlayPoint(x: 0.4, y: 0.4))

        viewModel.beginOverlayDrag(.media(ids[0]))
        // The photo keeps its place in the video (same tracks) but is fully transparent.
        let hidden = player.shown.last?.media.first { $0.id == ids[0] }
        #expect(hidden?.keyframes?.first?.opacity == 0)
        viewModel.moveMedia(ids[0], to: OverlayPoint(x: 0.3, y: 0.7))
        viewModel.endOverlayDrag()
        let landed = player.shown.last?.media.first { $0.id == ids[0] }
        #expect(landed?.keyframes == nil)
        #expect(landed?.center == OverlayPoint(x: 0.3, y: 0.7))
        // The drag was one undo step.
        viewModel.undo()
        #expect(viewModel.edit.media.first { $0.id == ids[0] }?.center == OverlayPoint(x: 0.5, y: 0.5))
    }
}

/// Motion presets from the editor: one undo step each, the keyframes untouched, the duration and strength kept when the preset
/// changes.
@MainActor
@Suite("Quick edit motion presets")
struct QuickEditMotionPresetTests {
    @Test func aPresetIsOneStepAndLeavesTheKeyframes() async throws {
        var take = TestData.take(scriptID: nil, number: 3)
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
        player.currentTime = 2
        viewModel.addText(.title)
        let id = try #require(viewModel.edit.texts.first?.id)
        viewModel.selection = .text(id)
        viewModel.toggleKeyframe()
        let keyframes = viewModel.edit.texts[0].keyframes
        let steps = viewModel.history.past.count
        viewModel.setMotionPreset(.slideUp)
        #expect(viewModel.edit.texts[0].animation?.preset == .slideUp)
        #expect(viewModel.edit.texts[0].keyframes == keyframes)
        #expect(viewModel.history.past.count == steps + 1)
        viewModel.setMotionDuration(1.2)
        viewModel.setMotionPreset(.pop)
        #expect(viewModel.edit.texts[0].animation?.duration == 1.2)
        viewModel.setMotionPreset(nil)
        #expect(viewModel.edit.texts[0].animation == nil)
        viewModel.undo()
        #expect(viewModel.edit.texts[0].animation?.preset == .pop)
    }
}
