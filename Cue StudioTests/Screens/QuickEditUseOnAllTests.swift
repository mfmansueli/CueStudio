//
//  QuickEditUseOnAllTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

/// "N clips keep their own · Use this on all" in the whole video's Adjust, Skin, Filters and Background: each counts and clears
/// only what it changes (Skin, Skin Smoothing; Filters, the filter and its amount; Background, the background; Adjust, its whole
/// set, never the filter or the background), in one undo step, and only when asked.
@MainActor
@Suite("Quick edit use this on all")
struct QuickEditUseOnAllTests {
    @MainActor
    private struct Scenario {
        let viewModel: QuickEditViewModel
        let player: FakeEditPlayback
        let toast: ToastService
        var clips: [EditSegment] { viewModel.edit.timeline.segments }
    }

    /// Three clips: 0–7.1, 7.1–10.1, 10.1–21.6.
    private func makeScenario() async -> Scenario {
        var take = TestData.take(scriptID: nil, number: 1)
        take.duration = 21.6
        let takes = TakeLibraryService(repository: FakeTakeRepository(takes: [take]))
        takes.load()
        let library = ScriptLibraryService(repository: FakeScriptRepository(scripts: []))
        library.load()
        let editor = FakeTakeEditor()
        editor.duration = 21.6
        let player = FakeEditPlayback()
        let toast = ToastService()
        let viewModel = QuickEditViewModel(
            take: takes.takes[0], takes: takes, library: library, editing: editor,
            drafts: FakeDraftStore(), toast: toast, player: player, styles: FakeTextStyleStore()
        )
        await viewModel.prepare()
        player.seek(to: 7.1)
        viewModel.clips.selectClipAtPlayhead()
        viewModel.clips.splitClip()
        player.seek(to: 10.1)
        viewModel.clips.splitClip()
        viewModel.selection = nil
        return Scenario(viewModel: viewModel, player: player, toast: toast)
    }

    /// Sets clip `index`'s own look, as one step.
    private func setLook(_ viewModel: QuickEditViewModel, clip index: Int, _ update: (inout ClipLook) -> Void) {
        viewModel.changeEdit { edit in
            var timeline = edit.timeline
            var clip = timeline.segments[index]
            var look = clip.look ?? ClipLook()
            update(&look)
            clip.look = look.normalized
            timeline.replaceSegment(clip)
            edit.timeline = timeline
        }
    }

    private var blur: BackgroundEffect {
        var effect = BackgroundEffect()
        effect.style = .blur
        return effect
    }

    @Test func filtersClearOnlyTheFilterAndItsAmountInOneStep() async {
        let scenario = await makeScenario()
        let viewModel = scenario.viewModel
        setLook(viewModel, clip: 0) { look in
            look.filter = .mono
            look.filterAmount = 0.5
            look.exposure = 12
        }
        setLook(viewModel, clip: 2) { $0.filterAmount = 0.3 }
        viewModel.perform(.openLook(.filters, wholeVideo: true))
        #expect(viewModel.look.clipsKeepingTheirOwnInPanel == 2)
        viewModel.look.useWholeVideosLookOnAllClips()
        #expect(scenario.clips[0].look?.filter == nil)
        #expect(scenario.clips[0].look?.filterAmount == nil)
        #expect(scenario.clips[0].look?.exposure == 12, "Adjust's own value stays")
        #expect(scenario.clips[2].look == nil)
        #expect(viewModel.look.clipsKeepingTheirOwnInPanel == 0)
        #expect(scenario.toast.message == "Every clip uses this now")
        #expect(scenario.toast.action != nil, "said with Undo")
        viewModel.undo()
        #expect(scenario.clips[0].look?.filter == .mono)
        #expect(scenario.clips[2].look?.filterAmount == 0.3)
    }

    @Test func skinCountsAndClearsEveryPartOfSkinAndNothingElse() async {
        let scenario = await makeScenario()
        let viewModel = scenario.viewModel
        setLook(viewModel, clip: 0) { look in
            look.skin = ClipSkin(smoothing: SkinSmoothing(amount: 30))
            look.exposure = 10
        }
        setLook(viewModel, clip: 1) { $0.contrast = -8 }
        // A 0 is a choice of the clip's own: it counts.
        setLook(viewModel, clip: 2) { $0.skin = ClipSkin(faceLight: 0) }
        viewModel.perform(.openLook(.skin, wholeVideo: true))
        #expect(viewModel.panel == .skin)
        #expect(viewModel.look.clipsKeepingTheirOwnInPanel == 2, "the clips with any part of Skin of their own")
        viewModel.look.useWholeVideosLookOnAllClips()
        #expect(scenario.clips[0].look?.skin == nil && scenario.clips[2].look == nil)
        #expect(scenario.clips[0].look?.exposure == 10)
        #expect(scenario.clips[1].look?.contrast == -8)
        viewModel.undo()
        #expect(scenario.clips[0].look?.skin?.smoothing?.amount == 30 && scenario.clips[2].look?.skin == ClipSkin(faceLight: 0))
        // Adjust counts its own set, never Skin.
        viewModel.closePanel()
        viewModel.perform(.openLook(.adjust, wholeVideo: true))
        #expect(viewModel.look.clipsKeepingTheirOwnInPanel == 2)
    }

    @Test func adjustClearsItsWholeSetButNeverTheFilterOrTheBackground() async {
        let scenario = await makeScenario()
        let viewModel = scenario.viewModel
        let background = blur
        setLook(viewModel, clip: 1) { look in
            look.exposure = 10
            look.tint = 4
            look.skin = ClipSkin(antiShine: 20)
            look.autoAmount = 0
            look.filter = .mono
            look.background = background
        }
        viewModel.perform(.openLook(.adjust, wholeVideo: true))
        #expect(viewModel.look.clipsKeepingTheirOwnInPanel == 1)
        viewModel.look.useWholeVideosLookOnAllClips()
        let look = scenario.clips[1].look
        #expect(look?.overridesAdjustment == false)
        #expect(look?.autoAmount == nil)
        #expect(look?.skin == ClipSkin(antiShine: 20), "Skin is not Adjust's")
        #expect(look?.filter == .mono)
        #expect(look?.background == background)
    }

    @Test func backgroundClearsOnlyTheBackground() async {
        let scenario = await makeScenario()
        let viewModel = scenario.viewModel
        let background = blur
        setLook(viewModel, clip: 2) { look in
            look.background = background
            look.saturation = 15
        }
        viewModel.perform(.openLook(.background, wholeVideo: true))
        #expect(viewModel.look.clipsKeepingTheirOwnInPanel == 1)
        viewModel.look.useWholeVideosLookOnAllClips()
        #expect(scenario.clips[2].look?.background == nil)
        #expect(scenario.clips[2].look?.saturation == 15)
    }

    @Test func aClipsOwnPanelOffersNothingToUseOnAll() async {
        let scenario = await makeScenario()
        let viewModel = scenario.viewModel
        setLook(viewModel, clip: 0) { $0.filter = .mono }
        setLook(viewModel, clip: 1) { $0.filter = .mono }
        viewModel.selection = .clip(scenario.clips[0].id)
        viewModel.perform(.openLook(.filters, wholeVideo: false))
        #expect(viewModel.look.clipsKeepingTheirOwnInPanel == 0)
        viewModel.look.useWholeVideosLookOnAllClips()
        #expect(scenario.clips[1].look?.filter == .mono, "nothing happens from a clip's panel")
    }

    @Test func aSliderHeldMeanwhileStaysItsOwnStep() async {
        let scenario = await makeScenario()
        let viewModel = scenario.viewModel
        setLook(viewModel, clip: 0) { $0.exposure = 25 }
        viewModel.perform(.openLook(.adjust, wholeVideo: true))
        // The whole video's Exposure, its ruler still held.
        viewModel.beginChange()
        viewModel.look.setAdjustment(.exposure, 30)
        viewModel.look.useWholeVideosLookOnAllClips()
        #expect(scenario.clips[0].look == nil)
        #expect(viewModel.edit.exposure == 30)
        // One Undo gives the clip its own back and keeps the whole video's change; the next takes that back.
        viewModel.undo()
        #expect(scenario.clips[0].look?.exposure == 25)
        #expect(viewModel.edit.exposure == 30)
        viewModel.undo()
        #expect(viewModel.edit.exposure == 0)
    }

    @Test func nothingIsClearedWithoutTheButton() async {
        let scenario = await makeScenario()
        let viewModel = scenario.viewModel
        setLook(viewModel, clip: 0) { $0.filter = .mono }
        viewModel.perform(.openLook(.filters, wholeVideo: true))
        viewModel.look.pickFilter(.vivid)
        viewModel.closePanel()
        #expect(scenario.clips[0].look?.filter == .mono)
    }
}
