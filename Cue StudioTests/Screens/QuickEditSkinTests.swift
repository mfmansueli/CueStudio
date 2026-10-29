//
//  QuickEditSkinTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

/// Skin in the editor, a panel of its own: nothing applied on opening, Natural and Studio setting every control, Custom once one
/// moves, the whole video or the picked clip alone (a 0 on a clip a choice), undo, a Reset and ◐ that never touch Adjust (and
/// Adjust's that never touch Skin), Paste look's Skin part, and a smoothing made with the first engine kept until "Update".
@MainActor
@Suite("Quick edit Skin")
struct QuickEditSkinTests {
    private struct Scenario {
        let viewModel: QuickEditViewModel
        let player: FakeEditPlayback
        let takes: TakeLibraryService
    }

    private func makeScenario(edit: TakeEdit? = nil) async -> Scenario {
        var take = TestData.take(scriptID: nil, number: 1)
        take.duration = 21.6
        take.edit = edit
        let takes = TakeLibraryService(repository: FakeTakeRepository(takes: [take]))
        takes.load()
        let library = ScriptLibraryService(repository: FakeScriptRepository(scripts: []))
        library.load()
        let editor = FakeTakeEditor()
        editor.duration = 21.6
        let player = FakeEditPlayback()
        let viewModel = QuickEditViewModel(
            take: takes.takes[0], takes: takes, library: library, editing: editor,
            drafts: FakeDraftStore(), toast: ToastService(), player: player, styles: FakeTextStyleStore()
        )
        await viewModel.prepare()
        return Scenario(viewModel: viewModel, player: player, takes: takes)
    }

    /// Three clips: 0–7.1, 7.1–10.1, 10.1–21.6.
    private func split(_ scenario: Scenario) {
        scenario.player.seek(to: 7.1)
        scenario.viewModel.clips.selectClipAtPlayhead()
        scenario.viewModel.clips.splitClip()
        scenario.player.seek(to: 10.1)
        scenario.viewModel.clips.splitClip()
        scenario.viewModel.selection = nil
    }

    private func openOnClip(_ viewModel: QuickEditViewModel, _ index: Int) {
        viewModel.closePanel()
        viewModel.selection = .clip(viewModel.edit.timeline.segments[index].id)
        viewModel.perform(.openLook(.skin, wholeVideo: false))
    }

    private func openOnVideo(_ viewModel: QuickEditViewModel) {
        viewModel.closePanel()
        viewModel.perform(.openLook(.skin, wholeVideo: true))
    }

    // MARK: - Opening and presets

    @Test func openingAppliesNothingAndStartsOff() async {
        let viewModel = (await makeScenario()).viewModel
        let before = viewModel.edit
        openOnVideo(viewModel)
        #expect(viewModel.panel == .skin)
        #expect(viewModel.edit == before && !viewModel.canUndo)
        #expect(viewModel.look.skinState == .off)
        #expect(LookViewModel.SkinControl.allCases.allSatisfy { $0 == .texture || viewModel.look.skinValue($0) == 0 })
        #expect(!viewModel.look.hasSkinSettings && !viewModel.look.skinCompare.isEnabled)
    }

    @Test func aPresetSetsEveryControlAtOnceAndAMovedControlIsCustom() async {
        let viewModel = (await makeScenario()).viewModel
        openOnVideo(viewModel)
        viewModel.look.applySkinPreset(.natural)
        #expect(viewModel.edit.skin == SkinPreset.natural.look)
        #expect(viewModel.look.skinState == .preset(.natural))
        viewModel.look.applySkinPreset(.studio)
        #expect(viewModel.edit.skin == SkinPreset.studio.look)
        viewModel.look.setSkin(.faceLight, 3)
        #expect(viewModel.look.skinState == .custom)
        #expect(viewModel.edit.skin.smoothing == SkinPreset.studio.look.smoothing, "the other controls stay")
        viewModel.undo()
        #expect(viewModel.look.skinState == .preset(.studio))
        viewModel.undo()
        #expect(viewModel.look.skinState == .preset(.natural))
        viewModel.undo()
        #expect(viewModel.edit.skin == .off)
    }

    /// Natural, then Studio: Skin's Reset and each control's stay, on the whole video and on a clip; Reset clip takes the clip's own Skin.
    @Test func afterOnePresetAndAnotherEveryResetIsStillThere() async {
        let scenario = await makeScenario()
        let viewModel = scenario.viewModel
        openOnVideo(viewModel)
        viewModel.look.applySkinPreset(.natural)
        viewModel.look.applySkinPreset(.studio)
        #expect(viewModel.look.hasSkinSettings, "Skin's Reset shows")
        #expect(LookViewModel.SkinControl.allCases.allSatisfy { viewModel.look.canResetSkin($0) })
        viewModel.look.resetSkin()
        #expect(viewModel.edit.skin == .off)
        split(scenario)
        openOnClip(viewModel, 1)
        viewModel.look.applySkinPreset(.natural)
        viewModel.look.applySkinPreset(.studio)
        #expect(viewModel.look.hasSkinSettings, "Skin's Reset shows")
        #expect(LookViewModel.SkinControl.allCases.allSatisfy { viewModel.look.canResetSkin($0) })
        viewModel.closePanel()
        viewModel.selection = .clip(viewModel.edit.timeline.segments[1].id)
        #expect(viewModel.clips.canResetClip)
        viewModel.perform(.resetClip)
        #expect(viewModel.edit.timeline.segments[1].look?.skin == nil)
        #expect(!viewModel.edit.hasSkin)
    }

    @Test func eachControlIsItsOwnAndStaysInRange() async {
        let viewModel = (await makeScenario()).viewModel
        openOnVideo(viewModel)
        viewModel.look.setSkin(.smoothing, 250)
        viewModel.look.setSkin(.texture, -10)
        viewModel.look.setSkin(.faceLight, 33.6)
        viewModel.look.setSkin(.antiShine, 12)
        let skin = viewModel.edit.skin
        #expect(skin.smoothing.amount == 100 && skin.smoothing.texture == 0)
        #expect(skin.smoothing.engine == ReadingVersion.skin.current)
        #expect(skin.faceLight == 34 && skin.antiShine == 12)
        #expect(viewModel.look.skinState == .custom)
    }

    @Test func aSlidersQuickMovesAreOneUndoStep() async {
        let viewModel = (await makeScenario()).viewModel
        openOnVideo(viewModel)
        for value in stride(from: 5.0, through: 60, by: 5) { viewModel.look.setSkin(.smoothing, value) }
        #expect(viewModel.edit.skin.smoothing.amount == 60)
        viewModel.undo()
        #expect(viewModel.edit.skin.smoothing.amount == 0)
        viewModel.redo()
        #expect(viewModel.edit.skin.smoothing.amount == 60)
    }

    @Test func refineWaitsForTheSmoothing() async {
        let viewModel = (await makeScenario()).viewModel
        openOnVideo(viewModel)
        #expect(!viewModel.look.canRefineTexture)
        viewModel.look.setSkin(.smoothing, 30)
        #expect(viewModel.look.canRefineTexture)
        viewModel.look.setSkin(.texture, 80)
        #expect(viewModel.edit.skin.smoothing.texture == 80)
    }

    // MARK: - Apart from Adjust

    @Test func resetAndAdjustNeverTouchEachOther() async {
        let viewModel = (await makeScenario()).viewModel
        viewModel.perform(.openLook(.adjust, wholeVideo: true))
        viewModel.look.setAdjustment(.exposure, 15)
        viewModel.look.pickFilter(.studio)
        openOnVideo(viewModel)
        viewModel.look.applySkinPreset(.natural)
        #expect(viewModel.edit.exposure == 15 && viewModel.edit.filter == .studio)
        // Skin's Reset: Skin off, Adjust and the filter stay.
        viewModel.look.resetSkin()
        #expect(viewModel.edit.skin == .off && viewModel.edit.exposure == 15 && viewModel.edit.filter == .studio)
        viewModel.undo()
        #expect(viewModel.edit.skin == SkinPreset.natural.look)
        // Adjust's Reset: the dials back, Skin stays.
        viewModel.perform(.openLook(.adjust, wholeVideo: true))
        viewModel.look.resetAdjustments()
        #expect(viewModel.edit.exposure == 0 && viewModel.edit.skin == SkinPreset.natural.look)
    }

    @Test func oneControlsResetLeavesTheOthers() async {
        let viewModel = (await makeScenario()).viewModel
        openOnVideo(viewModel)
        viewModel.look.applySkinPreset(.studio)
        #expect(viewModel.look.canResetSkin(.antiShine))
        viewModel.look.resetSkin(.antiShine)
        #expect(viewModel.edit.skin.antiShine == 0 && viewModel.edit.skin.faceLight == SkinPreset.studio.look.faceLight)
        #expect(!viewModel.look.canResetSkin(.antiShine))
        viewModel.look.resetSkin(.texture)
        #expect(viewModel.edit.skin.smoothing.texture == SkinBeautyCalibration.defaultTexture)
        #expect(viewModel.edit.skin.smoothing.amount == SkinPreset.studio.look.smoothing.amount)
    }

    @Test func skinsCompareHoldsOnlySkinAndTheOtherHoldsEverything() async {
        let scenario = await makeScenario()
        let viewModel = scenario.viewModel
        viewModel.perform(.openLook(.adjust, wholeVideo: true))
        viewModel.look.setAdjustment(.contrast, 20)
        openOnVideo(viewModel)
        viewModel.look.applySkinPreset(.studio)
        #expect(scenario.player.shown.last?.skin == SkinPreset.studio.look)
        viewModel.look.holdSkinComparison(true)
        #expect(scenario.player.shown.last?.skin == .off)
        #expect(scenario.player.shown.last?.contrast == 20, "only Skin is held back")
        #expect(viewModel.edit.skin == SkinPreset.studio.look, "what is saved doesn't change")
        viewModel.look.holdSkinComparison(false)
        #expect(scenario.player.shown.last?.skin == SkinPreset.studio.look)
        // The picture's ◐ (Adjust's) holds Skin back too.
        viewModel.look.holdPictureComparison(true)
        #expect(scenario.player.shown.last?.skin == .off && scenario.player.shown.last?.contrast == 0)
        viewModel.look.holdPictureComparison(false)
        #expect(scenario.player.shown.last?.skin == SkinPreset.studio.look)
    }

    @Test func isSavedWithTheEditWhenDone() async {
        let scenario = await makeScenario()
        openOnVideo(scenario.viewModel)
        scenario.viewModel.look.applySkinPreset(.natural)
        scenario.viewModel.look.setSkin(.texture, 72)
        scenario.viewModel.done()
        var expected = SkinPreset.natural.look
        expected.smoothing.texture = 72
        #expect(scenario.takes.takes[0].edit?.skin == expected)
    }

    // MARK: - Clips

    @Test func openedFromAClipItChangesThatClipOnly() async {
        let scenario = await makeScenario()
        let viewModel = scenario.viewModel
        split(scenario)
        openOnClip(viewModel, 1)
        #expect(viewModel.look.lookClip != nil)
        viewModel.look.setSkin(.faceLight, 50)
        #expect(viewModel.edit.skin == .off)
        #expect(viewModel.edit.timeline.segments[1].look?.skin == ClipSkin(faceLight: 50))
        #expect(viewModel.edit.timeline.segments[0].look == nil && viewModel.edit.timeline.segments[2].look == nil)
        #expect(viewModel.look.clipOverridesSkin(.faceLight) && !viewModel.look.clipOverridesSkin(.smoothing))
        // Moving the playhead never moves what the clip has.
        scenario.player.seek(to: 15)
        #expect(viewModel.edit.timeline.segments[1].look?.skin == ClipSkin(faceLight: 50))
    }

    /// A control's Reset on a clip turns it off there, the whole video's value too (the owner reset a clip showing the whole
    /// video's Studio and it stayed, 29/10/2026).
    @Test func aClipShowsTheVideosValuesUntilItSetsItsOwnAndResetTurnsThemOff() async {
        let scenario = await makeScenario()
        let viewModel = scenario.viewModel
        split(scenario)
        openOnVideo(viewModel)
        viewModel.look.applySkinPreset(.natural)
        openOnClip(viewModel, 2)
        #expect(viewModel.look.skinState == .preset(.natural) && !viewModel.look.clipOverridesSkin(.smoothing))
        viewModel.look.setSkin(.smoothing, 0)
        #expect(viewModel.look.skinValue(.smoothing) == 0 && viewModel.look.clipOverridesSkin(.smoothing), "a clip can turn it off")
        #expect(!viewModel.look.canResetSkin(.smoothing), "off already: nothing to reset")
        #expect(viewModel.edit.skin == SkinPreset.natural.look)
        // The clip's smoothing is set whole: the texture it played with goes with it.
        #expect(viewModel.edit.timeline.segments[2].look?.skin?.smoothing?.texture == SkinPreset.natural.look.smoothing.texture)
        viewModel.look.setSkin(.smoothing, 70)
        viewModel.look.resetSkin(.smoothing)
        #expect(viewModel.look.skinValue(.smoothing) == 0)
        #expect(viewModel.edit.timeline.segments[2].look?.skin?.smoothing?.amount == 0)
        // Face light shows the whole video's 15: its Reset is there, and turns it off on this clip alone.
        #expect(viewModel.look.canResetSkin(.faceLight) && !viewModel.look.clipOverridesSkin(.faceLight))
        viewModel.look.resetSkin(.faceLight)
        #expect(viewModel.look.skinValue(.faceLight) == 0 && viewModel.look.clipOverridesSkin(.faceLight))
        #expect(viewModel.edit.skin == SkinPreset.natural.look)
    }

    /// Natural on the whole video, then on a clip Natural, Studio and Reset: the clip has no Skin, the whole video keeps its
    /// own, and Reset clip has nothing left to say it isn't as filmed.
    @Test func resetOnAClipTurnsItsSkinOffEvenTheWholeVideos() async {
        let scenario = await makeScenario()
        let viewModel = scenario.viewModel
        split(scenario)
        openOnVideo(viewModel)
        viewModel.look.applySkinPreset(.studio)
        openOnClip(viewModel, 0)
        #expect(viewModel.look.hasSkinSettings, "the whole video's Studio shows on the clip, so Reset is there")
        viewModel.look.applySkinPreset(.natural)
        viewModel.look.applySkinPreset(.studio)
        #expect(viewModel.look.hasSkinSettings)
        viewModel.look.resetSkin()
        #expect(viewModel.look.skinState == .off)
        #expect(viewModel.edit.timeline.segments[0].look?.skin == ClipSkin(SkinLook()))
        #expect(viewModel.edit.skin == SkinPreset.studio.look)
        #expect(!viewModel.look.hasSkinSettings)
        #expect(!viewModel.edit.lookSettings(for: viewModel.edit.timeline.segments[0]).skin.isOn)
        #expect(viewModel.edit.lookSettings(for: viewModel.edit.timeline.segments[1]).skin.isOn, "the other clips keep it")
    }

    @Test func aPresetOnAClipAndItsResetGiveTheClipBackToTheVideo() async {
        let scenario = await makeScenario()
        let viewModel = scenario.viewModel
        split(scenario)
        openOnClip(viewModel, 0)
        viewModel.look.applySkinPreset(.studio)
        #expect(viewModel.edit.timeline.segments[0].look?.skin == ClipSkin(SkinPreset.studio.look))
        #expect(viewModel.edit.skin == .off)
        viewModel.look.resetSkin()
        #expect(viewModel.edit.timeline.segments[0].look == nil)
    }

    @Test func aClipsSkinSurvivesCuttingItAndUndoGivesTheOldValueBack() async {
        let scenario = await makeScenario()
        let viewModel = scenario.viewModel
        split(scenario)
        openOnClip(viewModel, 2)
        viewModel.look.setSkin(.antiShine, 40)
        viewModel.closePanel()
        scenario.player.seek(to: 15)
        viewModel.clips.selectClipAtPlayhead()
        viewModel.clips.splitClip()
        let segments = viewModel.edit.timeline.segments
        #expect(segments.count == 4)
        #expect(segments[2].look?.skin == ClipSkin(antiShine: 40) && segments[3].look?.skin == ClipSkin(antiShine: 40))
        viewModel.undo()
        viewModel.undo()
        #expect(viewModel.edit.timeline.segments[2].look == nil)
    }

    @Test func useThisOnAllRemovesOnlySkinOverrides() async {
        let scenario = await makeScenario()
        let viewModel = scenario.viewModel
        split(scenario)
        openOnClip(viewModel, 0)
        viewModel.look.setSkin(.smoothing, 0)
        openOnClip(viewModel, 1)
        viewModel.perform(.openLook(.adjust, wholeVideo: false))
        viewModel.look.setAdjustment(.exposure, 12)
        openOnVideo(viewModel)
        #expect(viewModel.look.clipsKeepingTheirOwnInPanel == 1)
        viewModel.look.useWholeVideosLookOnAllClips()
        #expect(viewModel.edit.timeline.segments[0].look == nil)
        #expect(viewModel.edit.timeline.segments[1].look?.exposure == 12)
        #expect(viewModel.look.clipsKeepingTheirOwnInPanel == 0)
    }

    // MARK: - Paste look

    @Test func pastingOnlySkinCarriesItsValuesTextureAndEngineAndLeavesAdjust() async {
        let scenario = await makeScenario()
        let viewModel = scenario.viewModel
        split(scenario)
        openOnClip(viewModel, 0)
        viewModel.look.setSkin(.smoothing, 45)
        viewModel.look.setSkin(.texture, 15)
        viewModel.look.setSkin(.faceLight, 25)
        viewModel.closePanel()
        viewModel.selection = .clip(viewModel.edit.timeline.segments[2].id)
        viewModel.perform(.openLook(.adjust, wholeVideo: false))
        viewModel.look.setAdjustment(.contrast, -10)
        viewModel.closePanel()
        viewModel.selection = .clip(viewModel.edit.timeline.segments[0].id)
        viewModel.look.copyClipLook()
        viewModel.selection = .clip(viewModel.edit.timeline.segments[2].id)
        viewModel.look.pastesLookParts = [.skin]
        viewModel.look.pasteLook(on: false)
        let pasted = viewModel.edit.timeline.segments[2].look
        #expect(pasted?.skin?.smoothing == SkinSmoothing(amount: 45, texture: 15))
        #expect(pasted?.skin?.faceLight == 25)
        #expect(pasted?.contrast == -10, "pasting Skin leaves the clip's Adjust")
        viewModel.undo()
        #expect(viewModel.edit.timeline.segments[2].look?.skin == nil)
        // Adjust alone leaves the clip's Skin.
        openOnClip(viewModel, 2)
        viewModel.look.setSkin(.antiShine, 30)
        viewModel.closePanel()
        viewModel.selection = .clip(viewModel.edit.timeline.segments[2].id)
        viewModel.look.pastesLookParts = [.adjust]
        viewModel.look.pasteLook(on: false)
        #expect(viewModel.edit.timeline.segments[2].look?.skin == ClipSkin(antiShine: 30))
    }

    // MARK: - The first engine

    private func olderEdit() -> TakeEdit {
        var edit = TakeEdit(sourceDuration: 21.6, aspect: .portrait)
        edit.skin = .firstEngine(80)
        return edit
    }

    @Test func anOlderSmoothingIsKeptAndSaysSo() async {
        let viewModel = (await makeScenario(edit: olderEdit())).viewModel
        openOnVideo(viewModel)
        #expect(viewModel.look.smoothingUsesFirstEngine && !viewModel.look.canRefineTexture)
        #expect(viewModel.look.skinState == .custom)
        // Turning it up or down keeps its engine; Light and Anti-shine never move it.
        viewModel.look.setSkin(.smoothing, 60)
        viewModel.look.setSkin(.faceLight, 20)
        viewModel.look.setSkin(.antiShine, 20)
        viewModel.look.setSkin(.texture, 10)
        #expect(viewModel.edit.skin.smoothing == SkinSmoothing(amount: 60, engine: 1))
    }

    @Test func updateMovesItToTodaysEngineAsOneStepThatUndoTakesBack() async {
        let viewModel = (await makeScenario(edit: olderEdit())).viewModel
        openOnVideo(viewModel)
        viewModel.look.updateSmoothing()
        let smoothing = viewModel.edit.skin.smoothing
        #expect(smoothing.engine == ReadingVersion.skin.current)
        #expect(smoothing.amount == SkinBeautyCalibration.updatedAmount(fromFirstEngine: 80))
        #expect(viewModel.look.canRefineTexture && !viewModel.look.smoothingUsesFirstEngine)
        viewModel.undo()
        #expect(viewModel.edit.skin.smoothing == SkinSmoothing(amount: 80, engine: 1))
    }

    @Test func aPresetOrTurningItOffAndOnAgainGivesTodaysEngine() async {
        let viewModel = (await makeScenario(edit: olderEdit())).viewModel
        openOnVideo(viewModel)
        viewModel.look.applySkinPreset(.natural)
        #expect(viewModel.edit.skin == SkinPreset.natural.look)
        viewModel.undo()
        viewModel.look.setSkin(.smoothing, 0)
        viewModel.look.setSkin(.smoothing, 30)
        #expect(viewModel.edit.skin.smoothing.engine == ReadingVersion.skin.current)
        viewModel.undo()
        #expect(viewModel.edit.skin.smoothing == SkinSmoothing(amount: 80, engine: 1), "one drag: Undo gives the older smoothing back")
    }

    @Test func aClipsOlderSmoothingIsUpdatedFromItsOwn() async {
        var edit = olderEdit()
        var clip = edit.timeline.segments[0]
        var look = ClipLook()
        look.skin = ClipSkin(smoothing: .firstEngine(40))
        clip.look = look
        edit.timeline.replaceSegment(clip)
        let viewModel = (await makeScenario(edit: edit)).viewModel
        openOnClip(viewModel, 0)
        #expect(viewModel.look.smoothingUsesFirstEngine && viewModel.look.skinValue(.smoothing) == 40)
        viewModel.look.updateSmoothing()
        #expect(viewModel.edit.timeline.segments[0].look?.skin?.smoothing?.engine == ReadingVersion.skin.current)
        #expect(viewModel.edit.skin.smoothing == SkinSmoothing(amount: 80, engine: 1), "the whole video's stays as it was")
    }
}
