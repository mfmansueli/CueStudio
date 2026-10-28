//
//  QuickEditClipToolsTests.swift
//  Cue StudioTests
//

import CoreGraphics
import Foundation
import Testing
@testable import Cue_Studio

/// The picked clip's newer tools (owner, 28/10/2026): Mirror (a switch), Crop with Rotate (the preview shows the whole picture
/// while it's open), Animation in and out, its sound's fades, and Reset clip, which puts everything back as filmed in one step.
@MainActor
@Suite("Quick edit · a clip's crop, mirror, animation, fades and reset")
struct QuickEditClipToolsTests {
    private struct Scenario {
        let viewModel: QuickEditViewModel
        let player: FakeEditPlayback
        let toast: ToastService
    }

    private func makeScenario() async -> Scenario {
        var take = TestData.take(scriptID: nil, number: 1)
        take.duration = 20
        let takes = TakeLibraryService(repository: FakeTakeRepository(takes: [take]))
        takes.load()
        let library = ScriptLibraryService(repository: FakeScriptRepository(scripts: []))
        library.load()
        let editor = FakeTakeEditor()
        editor.duration = 20
        let player = FakeEditPlayback()
        let toast = ToastService()
        let viewModel = QuickEditViewModel(
            take: takes.takes[0], takes: takes, library: library, editing: editor,
            drafts: FakeDraftStore(), toast: toast, player: player, styles: FakeTextStyleStore()
        )
        await viewModel.prepare()
        viewModel.perform(.selectClipAtPlayhead)
        return Scenario(viewModel: viewModel, player: player, toast: toast)
    }

    private func clip(_ viewModel: QuickEditViewModel) -> EditSegment { viewModel.edit.timeline.segments[0] }

    @Test func mirrorIsASwitchOnTheClipsBarAndUndoes() async {
        let viewModel = await makeScenario().viewModel
        #expect(viewModel.toolbarItems.first { $0.id == "mirror" }?.isOn == false)
        viewModel.perform(.toggleClipMirror)
        #expect(clip(viewModel).isMirrored)
        #expect(viewModel.toolbarItems.first { $0.id == "mirror" }?.isOn == true)
        viewModel.undo()
        #expect(!clip(viewModel).isMirrored)
    }

    @Test func cropShowsTheWholePictureWhileItIsOpenAndRotateTurnsIt() async {
        let viewModel = await makeScenario().viewModel
        let size = CGSize(width: 1080, height: 1920)
        viewModel.perform(.open(.clipCrop))
        #expect(viewModel.panel == .clipCrop)
        viewModel.clips.setClipCropShape(original: false, ratio: .square, pictureSize: size)
        #expect(clip(viewModel).crop?.ratio == .square)
        // The preview plays the clip whole, fitted, so the box is drawn over all of it.
        #expect(viewModel.playedEdit.timeline.segments[0].crop == nil)
        #expect(viewModel.playedEdit.cropFit == .fit)
        // A turn puts a box of a shape in the middle of the turned picture.
        viewModel.clips.rotateClip(recordingSize: size)
        #expect(clip(viewModel).quarterTurns == 1)
        let square = clip(viewModel).crop?.rect ?? .zero
        #expect(abs(square.width * 1920 - square.height * 1080) < 0.5)
        viewModel.panel = nil
        #expect(viewModel.playedEdit.timeline.segments[0].crop != nil)
        #expect(viewModel.playedEdit.cropFit == viewModel.edit.cropFit)
        // Original takes the box away; Reset in the panel's header puts the turn back too.
        viewModel.perform(.open(.clipCrop))
        viewModel.clips.setClipCropShape(original: true, ratio: nil, pictureSize: size)
        #expect(clip(viewModel).crop == nil)
        viewModel.panelReset(.clipCrop)?()
        #expect(clip(viewModel).quarterTurns == 0)
    }

    @Test func reorderAndFiltersShowTheClipTurned() async {
        let viewModel = await makeScenario().viewModel
        viewModel.clips.rotateClip(recordingSize: CGSize(width: 1080, height: 1920))
        #expect(viewModel.clips.clipList[0].orientation.quarterTurns == 1)
        viewModel.perform(.openLook(.filters, wholeVideo: false))
        #expect(viewModel.look.filterPreviewSource.orientation.quarterTurns == 1)
        // The whole video's: the clip that plays the take's first moments.
        viewModel.closePanel()
        viewModel.perform(.openLook(.filters, wholeVideo: true))
        #expect(viewModel.look.filterPreviewSource.orientation.quarterTurns == 1)
    }

    @Test func animationInAndOutPlayTheirEnd() async {
        let scenario = await makeScenario()
        let viewModel = scenario.viewModel
        viewModel.perform(.open(.clipAnimation))
        viewModel.clips.setClipAnimation(.slide, isIn: true)
        #expect(clip(viewModel).animationIn?.style == .slide)
        viewModel.clips.setClipAnimation(.zoom, isIn: false)
        viewModel.clips.setClipAnimationDuration(1.2, isIn: false)
        #expect(clip(viewModel).animationOut == ClipAnimation(style: .zoom, duration: 1.2))
        // Out keeps its length when its style changes; None takes it away.
        viewModel.clips.setClipAnimation(.fade, isIn: false)
        #expect(clip(viewModel).animationOut?.duration == 1.2)
        viewModel.clips.setClipAnimation(nil, isIn: true)
        #expect(clip(viewModel).animationIn == nil)
    }

    @Test func theClipsSoundFadesStayInTheirRange() async {
        let viewModel = await makeScenario().viewModel
        viewModel.clips.setClipSoundFadeIn(1.5)
        viewModel.clips.setClipSoundFadeOut(40)
        #expect(clip(viewModel).soundFadeIn == 1.5)
        #expect(clip(viewModel).soundFadeOut == EditSegment.soundFadeRange.upperBound)
        viewModel.panelReset(.volume)?()
        #expect(clip(viewModel).soundFadeIn == 0 && clip(viewModel).soundFadeOut == 0)
    }

    @Test func resetClipPutsEverythingBackInOneStep() async {
        let scenario = await makeScenario()
        let viewModel = scenario.viewModel
        #expect(viewModel.toolbarItems.first { $0.id == "resetClip" }?.style == .dimmed)
        viewModel.perform(.resetClip)
        #expect(scenario.toast.message == "This clip is already as filmed")
        viewModel.clips.updateClip { clip in
            clip.isMirrored = true
            clip.quarterTurns = 2
            clip.volume = 0.3
            clip.zoom = .pushIn
            clip.animationIn = ClipAnimation(style: .fade)
            clip.soundFadeOut = 1
        }
        viewModel.clips.setClipSpeed(2)
        let changed = clip(viewModel)
        #expect(viewModel.toolbarItems.first { $0.id == "resetClip" }?.style == .normal)
        viewModel.perform(.resetClip)
        #expect(clip(viewModel) == EditSegment(id: changed.id, sourceStart: changed.sourceStart, sourceEnd: changed.sourceEnd))
        #expect(scenario.toast.message == "Clip reset")
        viewModel.undo()
        #expect(clip(viewModel) == changed)
    }

    @Test func resetClipKeepsAClipMutedWhenItsSoundIsOnATrack() async {
        let viewModel = await makeScenario().viewModel
        viewModel.clips.updateClip { $0.isMuted = true }
        var sound = MusicClip(fileName: "sound.m4a", title: "Sound · Clip 1", fileDuration: 20, start: 0, length: 20)
        sound.extractedFrom = .clip
        viewModel.changeEdit { $0.music = [sound] }
        viewModel.clips.updateClip { $0.isMirrored = true }
        viewModel.perform(.resetClip)
        #expect(clip(viewModel).isMuted)
        #expect(!clip(viewModel).isMirrored)
    }
}
