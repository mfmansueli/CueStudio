//
//  PreviewMotionHoldTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

/// The preview's hold on the picked item (`PreviewMotionHold`, canvas 2 F15): where an item is whole, and a held item's moment
/// brought into it; anything else (another item, the export) is drawn at its own moment.
@Suite("Preview motion hold")
struct PreviewMotionHoldTests {
    @Test func popIsWholeOnceItHasComeIn() throws {
        let whole = try #require(PreviewMotionHold.wholePart(animation: OverlayAnimation(preset: .pop, duration: 0.5), effect: nil, length: 4))
        #expect(whole == 0.5...4)
        // Its way in is over there: full size and opaque.
        let settled = OverlayAnimation(preset: .pop, duration: 0.5).modifier(at: whole.lowerBound, length: 4)
        #expect(abs(settled.scale - 1) < 0.001 && settled.opacity == 1)
    }

    @Test func inAndOutIsWholeBetweenItsWayInAndItsWayOut() throws {
        let animation = OverlayAnimation(preset: .inAndOut, duration: 0.6)
        let whole = try #require(PreviewMotionHold.wholePart(animation: animation, effect: nil, length: 4))
        #expect(abs(whole.lowerBound - 0.6) < 0.001 && abs(whole.upperBound - 3.4) < 0.001)
        #expect(animation.modifier(at: whole.upperBound, length: 4).opacity == 1, "Still whole where its way out begins")
        #expect(animation.modifier(at: 4, length: 4).opacity == 0, "Gone at its very end, as the video shows")
    }

    @Test func aShortItemIsHeldWhereItsWayInAndOutMeet() throws {
        let whole = try #require(PreviewMotionHold.wholePart(animation: OverlayAnimation(preset: .inAndOut, duration: 1.5), effect: nil, length: 1))
        #expect(whole == 0.5...0.5)
    }

    @Test func aSlowZoomKeyframesAloneOrNothingHoldNothing() {
        #expect(PreviewMotionHold.wholePart(animation: OverlayAnimation(preset: .gentleZoom), effect: nil, length: 4) == nil)
        #expect(PreviewMotionHold.wholePart(animation: nil, effect: nil, length: 4) == nil)
    }

    @Test func aMovingEffectIsWholeBetweenItsOwnWayInAndOut() throws {
        let effect = TextEffect(.wave)
        let whole = try #require(PreviewMotionHold.wholePart(animation: nil, effect: effect, length: 4))
        let timing = TextEffectChoreography.timing(effect, length: 4)
        #expect(whole == timing.entrance...(4 - timing.exit))
    }

    @Test func onlyTheHeldItemsMomentMoves() {
        let hold = PreviewMotionHold()
        let id = UUID()
        hold.set(PreviewMotionHold.Hold(id: id, whole: 0.5...3.5))
        #expect(hold.local(0, of: id) == 0.5)
        #expect(hold.local(2, of: id) == 2)
        #expect(hold.local(3.9, of: id) == 3.5)
        #expect(hold.local(0, of: UUID()) == 0, "Another item plays its own way in")
        #expect(hold.local(0, of: nil) == 0)
        #expect(!hold.set(PreviewMotionHold.Hold(id: id, whole: 0.5...3.5)), "The same hold changes nothing")
        #expect(hold.set(nil))
        #expect(hold.local(0, of: id) == 0)
    }

    /// A text with Pop, held: the editor's preview draws it whole on its first frame (as big as it is once in), while the same
    /// text built for the export still pops in from smaller there. The hold is for this text alone (a new id), so it never
    /// reaches another test's drawing.
    @Test func theHeldTextIsWholeOnItsFirstFrameOnlyInThePreview() throws {
        var text = TextOverlay(role: .title, style: .bold, span: TimeSpan(start: 0, end: 3))
        text.text = "Hello"
        text.animation = OverlayAnimation(preset: .pop, duration: 0.5, intensity: 1)
        let span = TimeSpan(start: 1, end: 4)
        let exported = try #require(TextOverlayRenderer.overlays([(text, span)], frame: CGSize(width: 360, height: 640)).first)
        var previewed = exported
        previewed.readsPreviewHold = true
        let cache = OverlayImageCache()
        PreviewMotionHold.shared.set(PreviewMotionHold.Hold(id: text.id, whole: 0.5...3))
        defer { PreviewMotionHold.shared.set(nil) }
        let whole = try #require(exported.placed(at: 2, cache: cache)).extent
        let held = try #require(previewed.placed(at: 1, cache: cache)).extent
        let popping = try #require(exported.placed(at: 1, cache: cache)).extent
        #expect(abs(held.width - whole.width) < 1 && abs(held.height - whole.height) < 1, "Held: as big as it is once in")
        #expect(popping.width < whole.width - 5, "The export's first frame still pops in")
    }

    /// The export never reads the hold; the editor's preview does.
    @Test func onlyTheEditorsPreviewShowsThePickedItemWhole() {
        #expect(EditRenderPurpose.editorPreview(rendersCurveSound: true).options.showsPickedWhole)
        #expect(!EditRenderPurpose.reviewPreview.options.showsPickedWhole)
        #expect(!EditRenderPurpose.export(burnsInCaptions: true, shortSide: 1080, frameRate: nil).options.showsPickedWhole)
    }
}
