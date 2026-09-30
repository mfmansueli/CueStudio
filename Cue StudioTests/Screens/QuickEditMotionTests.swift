//
//  QuickEditMotionTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

/// Keyframes, section zooms and caption animations in Quick edit.
@MainActor
@Suite("Quick edit motion")
struct QuickEditMotionTests {
    private struct Scenario {
        let viewModel: QuickEditViewModel
        let player: FakeEditPlayback
        let toast: ToastService
    }

    private func makeScenario() async -> Scenario {
        let script = TestData.script(text: "Okay, real talk.")
        var take = TestData.take(scriptID: script.id, number: 3)
        take.duration = 64
        let takes = TakeLibraryService(repository: FakeTakeRepository(takes: [take]))
        takes.load()
        let library = ScriptLibraryService(repository: FakeScriptRepository(scripts: [script]))
        library.load()
        let player = FakeEditPlayback()
        let toast = ToastService()
        let viewModel = QuickEditViewModel(
            take: takes.takes[0], takes: takes, library: library, editing: FakeTakeEditor(),
            drafts: FakeDraftStore(), toast: toast, player: player,
            mediaImporter: FakeMediaImporter(), recorder: FakeVoiceRecorder(), styles: FakeTextStyleStore()
        )
        await viewModel.prepare()
        return Scenario(viewModel: viewModel, player: player, toast: toast)
    }

    // MARK: - Keyframes

    @Test func aKeyframeStartsWhereTheTextIsAndMovesItOverTime() async throws {
        let scenario = await makeScenario()
        let viewModel = scenario.viewModel
        scenario.player.currentTime = 10
        viewModel.addText(.title)
        viewModel.editingTextID = nil
        let id = viewModel.edit.texts[0].id
        let start = viewModel.edit.texts[0].center
        viewModel.toggleKeyframe()
        #expect(viewModel.edit.texts[0].keyframes.map(\.time) == [0])
        #expect(viewModel.edit.texts[0].keyframes[0].center == start)

        // Later on, moving it on the preview sets a second keyframe there.
        scenario.player.currentTime = 12
        viewModel.moveText(id, to: OverlayPoint(x: 0.3, y: 0.6))
        #expect(viewModel.edit.texts[0].keyframes.map(\.time) == [0, 2])
        #expect(viewModel.edit.texts[0].center == start)
        scenario.player.currentTime = 11
        let halfway = viewModel.motionState(of: .text(id))
        #expect(halfway.center.x < start.x && halfway.center.x > 0.3)
        #expect(viewModel.textBars[0].keyframes == [0, 2])

        viewModel.undo()
        #expect(viewModel.edit.texts[0].keyframes.count == 1)
    }

    @Test func withoutKeyframesMovingATextMovesIt() async {
        let scenario = await makeScenario()
        let viewModel = scenario.viewModel
        viewModel.addText(.title)
        let id = viewModel.edit.texts[0].id
        viewModel.moveText(id, to: OverlayPoint(x: 0.3, y: 0.6))
        #expect(viewModel.edit.texts[0].center == OverlayPoint(x: 0.3, y: 0.6))
        #expect(viewModel.edit.texts[0].keyframes.isEmpty)
    }

    @Test func keyframesAreVisitedAndTakenAway() async {
        let scenario = await makeScenario()
        let viewModel = scenario.viewModel
        scenario.player.currentTime = 5
        viewModel.addText(.subtitle)
        viewModel.editingTextID = nil
        viewModel.toggleKeyframe()
        scenario.player.currentTime = 7
        viewModel.toggleKeyframe()
        viewModel.setKeyframeOpacity(0.25)
        viewModel.setKeyframeEasing(.linear)
        let keyframes = viewModel.edit.texts[0].keyframes
        #expect(keyframes[1].opacity == 0.25)
        #expect(keyframes[1].easing == .linear)
        viewModel.jumpToKeyframe(forward: false)
        #expect(scenario.player.currentTime == 5)
        viewModel.jumpToKeyframe(forward: true)
        #expect(scenario.player.currentTime == 7)
        viewModel.toggleKeyframe()
        #expect(viewModel.edit.texts[0].keyframes.count == 1)
    }

    @Test func aKeyframeNeedsTheItemOnScreen() async {
        let scenario = await makeScenario()
        let viewModel = scenario.viewModel
        scenario.player.currentTime = 5
        viewModel.addText(.hook)
        scenario.player.currentTime = 40
        viewModel.toggleKeyframe()
        #expect(viewModel.edit.texts[0].keyframes.isEmpty)
        #expect(scenario.toast.message == "Move the playhead over it to add a keyframe")
    }

    // MARK: - Zooms

    @Test func aZoomGoesOnTheWholeVideoOrOneSection() async {
        let scenario = await makeScenario()
        let viewModel = scenario.viewModel
        viewModel.setZoom(.pushIn)
        #expect(viewModel.edit.timeline.segments.allSatisfy { $0.zoom == .pushIn })
        #expect(viewModel.currentZoom == .some(.pushIn))
        scenario.player.currentTime = 30
        viewModel.cut()
        viewModel.speedScope = .section
        viewModel.setZoom(.punchIn)
        #expect(viewModel.edit.timeline.segments.map(\.zoom) == [.pushIn, .punchIn])
        viewModel.undo()
        #expect(viewModel.edit.timeline.segments.map(\.zoom) == [.pushIn, .pushIn])
    }

    // MARK: - Captions

    @Test func anAnimationIsOneStepAndDrawsWithAPreset() async {
        let scenario = await makeScenario()
        let viewModel = scenario.viewModel
        viewModel.setCaptionAnimation(.highlight)
        #expect(viewModel.edit.captionAnimation == .highlight)
        #expect(viewModel.edit.captionPreset == .cue)
        viewModel.undo()
        #expect(viewModel.edit.captionAnimation == .line)
        #expect(viewModel.edit.captionLook == nil)
    }

    @Test func linesWithoutWordTimesAreCounted() async {
        let scenario = await makeScenario()
        let viewModel = scenario.viewModel
        viewModel.makeCaptions()
        await viewModel.captionTask?.value
        #expect(viewModel.linesWithoutWordTiming == 0)
        viewModel.setCaptionText(viewModel.edit.captions[0].id, "Okay, so real talk.")
        #expect(viewModel.linesWithoutWordTiming == 1)
    }
}
