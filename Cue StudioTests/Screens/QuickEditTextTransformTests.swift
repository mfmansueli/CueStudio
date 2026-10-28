//
//  QuickEditTextTransformTests.swift
//  Cue StudioTests
//

import CoreGraphics
import Foundation
import Testing
@testable import Cue_Studio

/// A text handled by hand and restyled: a gesture's move, resize and turn land as one undo step inside the limits the picture
/// kept to while the fingers moved; a text resized as a whole keeps where its lines break; with keyframes, the keyframe at the
/// playhead takes it; a style (an effect or not) changes the look and never the words, the place, the size set by hand, the
/// turn, the timing, the clip or the keyframes.
@MainActor
@Suite("Quick edit · text by hand")
struct QuickEditTextTransformTests {
    private struct Scenario {
        let viewModel: QuickEditViewModel
        let player: FakeEditPlayback
        let toast: ToastService
    }

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
            drafts: FakeDraftStore(), toast: toast, player: player,
            mediaImporter: FakeMediaImporter(), recorder: FakeVoiceRecorder(), styles: FakeTextStyleStore()
        )
        await viewModel.prepare()
        return Scenario(viewModel: viewModel, player: player, toast: toast)
    }

    private func addTitle(_ viewModel: QuickEditViewModel, words: String = "ola tudo bem") throws -> UUID {
        viewModel.overlays.addStyledText(.title)
        let id = try #require(viewModel.selectedTextID)
        viewModel.overlays.setTextContent(id, words)
        viewModel.overlays.endAllChanges()
        return id
    }

    private func text(_ viewModel: QuickEditViewModel, _ id: UUID) throws -> TextOverlay {
        try #require(viewModel.edit.texts.first { $0.id == id })
    }

    // MARK: - Gestures

    @Test func aGestureMovesResizesAndTurnsInOneUndoStep() async throws {
        let viewModel = await makeScenario().viewModel
        let id = try addTitle(viewModel)
        let before = try text(viewModel, id)
        viewModel.overlays.transformText(id, center: OverlayPoint(x: 0.3, y: 0.6), factor: 1.5, rotation: 0.4)
        let after = try text(viewModel, id)
        #expect(after.center == OverlayPoint(x: 0.3, y: 0.6))
        #expect(abs(after.size - before.size * 1.5) < 0.001)
        #expect(abs(after.rotation - 0.4) < 0.000_1)
        #expect(after.customized.isSuperset(of: [.position, .size]))
        #expect(after.text == before.text && after.span == before.span)
        viewModel.undo()
        #expect(try text(viewModel, id) == before)
    }

    @Test func resizingAsAWholeKeepsWhereTheLinesBreak() async throws {
        let viewModel = await makeScenario().viewModel
        let id = try addTitle(viewModel, words: "Uma frase comprida que quebra em duas linhas")
        let before = try text(viewModel, id)
        #expect(before.block == nil)
        viewModel.overlays.transformText(id, center: before.center, factor: 1.6, rotation: 0)
        let after = try text(viewModel, id)
        let block = try #require(after.block)
        #expect(abs(block.width - TextOverlayRenderer.currentLineWidth(of: before)) < 0.001)
        let width: CGFloat = 1080
        let small = TextOverlayRenderer.size(for: before, frameWidth: width)
        let big = TextOverlayRenderer.size(for: after, frameWidth: width)
        // Its lines are the same: the box is 1.6 times as tall, not reflowed into more lines.
        #expect(abs(big.height / small.height - 1.6) < 0.04, "\(small) → \(big)")
    }

    @Test func theLimitsAreTheSameWhileMovingAndWhenLifted() async throws {
        let viewModel = await makeScenario().viewModel
        let id = try addTitle(viewModel)
        let before = try text(viewModel, id)
        let allowed = viewModel.overlays.allowedScale(50, forText: before)
        #expect(abs(before.size * allowed - TextOverlay.sizeRange.upperBound) < 0.001)
        viewModel.overlays.transformText(id, center: before.center, factor: 50, rotation: 0)
        #expect(try text(viewModel, id).size == TextOverlay.sizeRange.upperBound)
        #expect(viewModel.overlays.allowedScale(.nan, forText: before) == 1)
    }

    @Test func withKeyframesTheKeyframeAtThePlayheadTakesIt() async throws {
        let scenario = await makeScenario()
        let viewModel = scenario.viewModel
        scenario.player.seek(to: 1)
        let id = try addTitle(viewModel)
        viewModel.overlays.toggleKeyframe()
        scenario.player.seek(to: 2)
        let base = try text(viewModel, id)
        viewModel.overlays.transformText(id, center: OverlayPoint(x: 0.4, y: 0.4), factor: 2, rotation: -0.5)
        let after = try text(viewModel, id)
        #expect(after.keyframes.count == 2)
        let last = try #require(after.keyframes.last)
        #expect(last.center == OverlayPoint(x: 0.4, y: 0.4))
        #expect(abs(last.scale - 2) < 0.001)
        #expect(abs((last.rotation ?? 0) + 0.5) < 0.000_1)
        // The text itself stays: only its keyframe moved.
        #expect(after.size == base.size && after.center == base.center && after.rotation == base.rotation)
        #expect(abs(viewModel.overlays.rotation(ofText: after) + 0.5) < 0.000_1)
        viewModel.undo()
        #expect(try text(viewModel, id).keyframes.count == 1)
    }

    @Test func aSideHandleSetsTheLinesLengthAndKeepsTheSize() async throws {
        let viewModel = await makeScenario().viewModel
        let id = try addTitle(viewModel)
        let before = try text(viewModel, id)
        viewModel.overlays.setTextBlock(id, width: 120, center: OverlayPoint(x: 0.45, y: before.center.y))
        let after = try text(viewModel, id)
        #expect(after.block == TextBlock(width: 120, size: before.size))
        #expect(after.size == before.size)
        #expect(after.center.x == 0.45)
        viewModel.undo()
        #expect(try text(viewModel, id).block == nil)
    }

    @Test func aTurnSticksToStraightNearIt() {
        #expect(OverlaysViewModel.snappedRotation(.pi / 2 + 0.03) == (.pi / 2, true))
        #expect(OverlaysViewModel.snappedRotation(0.3).snapped == false)
        #expect(abs(OverlaysViewModel.normalizedRotation(3 * .pi / 2) + .pi / 2) < 0.000_1)
    }

    @Test func voiceOverTurnsAStepAtATime() async throws {
        let viewModel = await makeScenario().viewModel
        let id = try addTitle(viewModel)
        viewModel.overlays.turnText(id, clockwise: true)
        #expect(abs(try text(viewModel, id).rotation - OverlaysViewModel.rotationStep) < 0.000_1)
        viewModel.overlays.turnText(id, clockwise: false)
        #expect(try text(viewModel, id).rotation == 0)
    }

    @Test func theTurnSliderIsOneUndoStepPerDrag() async throws {
        let viewModel = await makeScenario().viewModel
        let id = try addTitle(viewModel)
        viewModel.overlays.beginPanelChange()
        for degrees in stride(from: 1.0, through: 30, by: 1) { viewModel.overlays.setTextTurn(degrees: degrees) }
        viewModel.overlays.endPanelChange()
        #expect(viewModel.overlays.pickedTextTurnDegrees == 30)
        viewModel.undo()
        #expect(try text(viewModel, id).rotation == 0)
    }

    // MARK: - Styles

    @Test func aStyleKeepsTheWordsThePlaceTheSizeSetByHandAndTheTiming() async throws {
        let scenario = await makeScenario()
        let viewModel = scenario.viewModel
        scenario.player.seek(to: 1)
        let id = try addTitle(viewModel, words: "Olá, ação 👩🏽‍💻")
        viewModel.overlays.transformText(id, center: OverlayPoint(x: 0.3, y: 0.25), factor: 1.4, rotation: 0.2)
        viewModel.overlays.toggleKeyframe()
        let placed = try text(viewModel, id)
        for preset in TypePreset.effectPresets + [.orbit, .postcard] {
            viewModel.overlays.pickTextPreset(preset)
            let styled = try text(viewModel, id)
            #expect(styled.text == placed.text, "\(preset)")
            #expect(styled.center == placed.center, "\(preset)")
            #expect(styled.size == placed.size, "\(preset)")
            #expect(styled.rotation == placed.rotation, "\(preset)")
            #expect(styled.span == placed.span && styled.clipAnchor == placed.clipAnchor, "\(preset)")
            #expect(styled.keyframes == placed.keyframes, "\(preset)")
            #expect(styled.effect?.kind == preset.effect, "\(preset)")
        }
    }

    @Test func anEffectThatMovesTakesTheMotionOffAndSaysSoWithUndo() async throws {
        let scenario = await makeScenario()
        let viewModel = scenario.viewModel
        let id = try addTitle(viewModel)
        viewModel.overlays.setMotionPreset(.fade)
        viewModel.overlays.pickTextPreset(.gold)
        let styled = try text(viewModel, id)
        // It moves as its card shows: the Motion would have played instead of its way in.
        #expect(styled.animation == nil && styled.playsEffectMotion)
        #expect(scenario.toast.message == "Gold metal on this text · Motion removed, the style moves it")
        #expect(scenario.toast.action != nil)
        viewModel.undo()
        #expect(try text(viewModel, id).animation?.preset == .fade)
    }

    @Test func aMotionStillsTheEffectAndEffectsOwnGivesItsMotionBack() async throws {
        let viewModel = await makeScenario().viewModel
        let id = try addTitle(viewModel)
        viewModel.overlays.pickTextPreset(.wave)
        // A Motion picked in Custom: it moves the text, the effect keeps its finish and stays still.
        viewModel.overlays.setMotionPreset(.slideUp)
        var styled = try text(viewModel, id)
        #expect(styled.animation?.preset == .slideUp && styled.effect?.kind == .wave && styled.effect?.motion == .still)
        viewModel.overlays.playEffectsOwnMotion()
        styled = try text(viewModel, id)
        #expect(styled.animation == nil && styled.playsEffectMotion)
        // None: nothing moves it in, the finish stays.
        viewModel.overlays.setMotionPreset(nil)
        styled = try text(viewModel, id)
        #expect(styled.animation == nil && styled.effect?.kind == .wave && styled.effect?.motion == .still)
        // Animated in the effect's settings: it moves again, and a Motion picked since goes.
        viewModel.overlays.setMotionPreset(.pop)
        viewModel.overlays.restyleText(.effectMotion(.animated))
        styled = try text(viewModel, id)
        #expect(styled.animation == nil && styled.playsEffectMotion)
        viewModel.undo()
        #expect(try text(viewModel, id).animation?.preset == .pop)
    }

    @Test func aStillEffectKeepsAMotion() async throws {
        let viewModel = await makeScenario().viewModel
        let id = try addTitle(viewModel)
        viewModel.overlays.pickTextPreset(.gold)
        viewModel.overlays.restyleText(.effectMotion(.still))
        viewModel.overlays.saveTextStyle(named: "Still gold")
        let saved = try #require(viewModel.overlays.textStyles.styles.first)
        viewModel.overlays.pickTextPreset(.orbit)
        viewModel.overlays.setMotionPreset(.fade)
        // A saved style whose effect is still has no way in of its own: the Motion stays.
        viewModel.overlays.pickSavedTextStyle(saved.id)
        let styled = try text(viewModel, id)
        #expect(styled.effect?.kind == .gold && styled.effect?.motion == .still)
        #expect(styled.animation?.preset == .fade)
    }

    @Test func anEffectsSettingsChangeOnlyATextThatWearsOne() async throws {
        let viewModel = await makeScenario().viewModel
        let id = try addTitle(viewModel)
        viewModel.overlays.pickTextPreset(.orbit)
        viewModel.overlays.restyleText(.effectIntensity(0.2))
        #expect(try text(viewModel, id).effect == nil)
        viewModel.overlays.pickTextPreset(.pop3D)
        viewModel.overlays.restyleText(.effectIntensity(0.2))
        viewModel.overlays.restyleText(.effectAccent(.blue))
        viewModel.overlays.restyleText(.effectDirection(.left))
        viewModel.overlays.restyleText(.effectDirection(.middle))
        let effect = try #require(try text(viewModel, id).effect)
        #expect(effect.intensity == 0.2 && effect.accent == .blue && effect.direction == .left)
        viewModel.overlays.restyleText(.removeEffect)
        let plain = try text(viewModel, id)
        #expect(plain.effect == nil && plain.preset == nil)
        #expect(plain.font == TypePreset.pop3D.look(for: .title).font)
    }
}
