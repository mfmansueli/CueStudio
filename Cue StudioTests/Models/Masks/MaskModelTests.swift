//
//  MaskModelTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

/// A photo's or video's mask: where a new one starts (a circle round on screen), another shape keeping its place, its values
/// kept in range, its turn taking the short way between keyframes, and the keyframes with a mask moving it over time.
@Suite("Mask")
struct MaskModelTests {
    @Test func aNewCircleIsRoundOnScreen() {
        let wide = MediaMask.starting(.circle, onPlaceOfAspect: 16.0 / 9)
        #expect(abs(wide.placement.width * 16 / 9 - wide.placement.height) < 0.000_1)
        let tall = MediaMask.starting(.circle, onPlaceOfAspect: 9.0 / 16)
        #expect(abs(tall.placement.width * 9 / 16 - tall.placement.height) < 0.000_1)
    }

    @Test func anotherShapeKeepsWhereItIsAndHowSoft() {
        var mask = MediaMask.starting(.rectangle, onPlaceOfAspect: 1)
        mask.placement.center = OverlayPoint(x: 0.3, y: 0.7)
        mask.placement.rotation = 20
        mask.placement.feather = 0.4
        mask.placement.width = 0.5
        mask.inverted = true
        let circle = mask.reshaped(.circle, onPlaceOfAspect: 1)
        #expect(circle.shape == .circle)
        #expect(circle.placement.center == OverlayPoint(x: 0.3, y: 0.7))
        #expect(circle.placement.rotation == 20 && circle.placement.feather == 0.4 && circle.inverted)
        #expect(circle.placement.width == 0.5, "a size carries between shapes that have one")
        let line = mask.reshaped(.line, onPlaceOfAspect: 1)
        #expect(line.placement.center == OverlayPoint(x: 0.3, y: 0.7))
    }

    @Test func valuesStayInRange() {
        let wild = MaskPlacement(center: OverlayPoint(x: 9, y: -9), width: 0, height: 99, rotation: 540, feather: 3, corners: -1).clamped
        #expect(wild.center.x == MaskPlacement.centerRange.upperBound && wild.center.y == MaskPlacement.centerRange.lowerBound)
        #expect(wild.width == MaskPlacement.sizeRange.lowerBound && wild.height == MaskPlacement.sizeRange.upperBound)
        #expect(wild.rotation == 180)
        #expect(wild.feather == 1 && wild.corners == 0)
    }

    @Test func theTurnTakesTheShortWayRound() {
        let from = MaskPlacement(rotation: 170), to = MaskPlacement(rotation: -170)
        #expect(abs(from.interpolated(to: to, progress: 0.5).rotation - 180) < 0.000_1)
    }

    @Test func keyframesWithAMaskMoveItAndTheOthersLeaveIt() {
        let small = MaskPlacement(width: 0.2, height: 0.2), big = MaskPlacement(width: 0.8, height: 0.8)
        let keyframes = [
            OverlayKeyframe(time: 0, center: .center, easing: .linear, mask: small),
            OverlayKeyframe(time: 1, center: OverlayPoint(x: 0.3, y: 0.5), easing: .linear),
            OverlayKeyframe(time: 2, center: .center, easing: .linear, mask: big),
        ]
        let motion = OverlayMotion(keyframes)
        #expect(abs((motion.state(at: 1)?.mask?.width ?? 0) - 0.5) < 0.000_1, "halfway between the two with a mask")
        #expect(motion.state(at: 5)?.mask == big)
        #expect(OverlayMotion([OverlayKeyframe(time: 0, center: .center)]).state(at: 0)?.mask == nil)
    }

    @Test func aMaskReadsBackAndANewerShapeReadsAsARectangle() throws {
        let mask = MediaMask(shape: .band, placement: MaskPlacement(height: 0.3, rotation: 15, feather: 0.2), inverted: true)
        #expect(try JSONDecoder().decode(MediaMask.self, from: JSONEncoder().encode(mask)) == mask)
        let newer = Data(#"{"shape":"heart","placement":{"width":0.4},"inverted":false}"#.utf8)
        let read = try JSONDecoder().decode(MediaMask.self, from: newer)
        #expect(read.shape == .rectangle && read.placement.width == 0.4)
        // Media saved before masks read with none.
        var media = MediaOverlay(kind: .photo, fileName: "a.jpg", aspect: 1, mediaDuration: nil, span: TimeSpan(start: 0, end: 3))
        media.mask = mask
        var json = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(media)) as? [String: Any])
        json["mask"] = nil
        #expect(try JSONDecoder().decode(MediaOverlay.self, from: JSONSerialization.data(withJSONObject: json)).mask == nil)
    }
}
