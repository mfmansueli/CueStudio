//
//  BlurRegionTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

/// A Blur area: where it is between keyframes, what's left unchecked and how lengthening it marks the new part, its strength
/// never weak, a face's area covering the head, and reading what an older or newer Cue wrote.
@MainActor
@Suite("Blur area")
struct BlurRegionTests {
    private func region() -> BlurRegion {
        BlurRegion(target: .recording(nil), span: TimeSpan(start: 1, end: 5), box: NormalizedBox(x: 0.1, y: 0.1, width: 0.2, height: 0.2))
    }

    @Test func itMovesBetweenKeyframesAndHoldsPastThem() {
        var area = region()
        area.keyframes = [
            BlurKeyframe(time: 2, box: NormalizedBox(x: 0.1, y: 0.1, width: 0.2, height: 0.2)),
            BlurKeyframe(time: 4, box: NormalizedBox(x: 0.5, y: 0.3, width: 0.2, height: 0.2)),
        ]
        #expect(area.box(at: 1).x == 0.1)
        #expect(abs(area.box(at: 3).x - 0.3) < 0.000_1)
        #expect(abs(area.box(at: 3).y - 0.2) < 0.000_1)
        #expect(area.box(at: 4.8).x == 0.5)
        #expect(area.moves)
        #expect(!region().moves)
    }

    @Test func itIsCoveredOnlyWhenFollowedAndNothingIsLeftUnchecked() {
        var area = region()
        #expect(!area.isCovered)
        area.isFollowed = true
        #expect(area.isCovered)
        area.markUnchecked(TimeSpan(start: 3, end: 4))
        #expect(!area.isCovered)
        #expect(abs(area.uncheckedDuration - 1) < 0.000_1)
        area.markChecked(TimeSpan(start: 3, end: 3.5))
        #expect(area.openUnchecked == [TimeSpan(start: 3.5, end: 4)])
        area.markChecked(TimeSpan(start: 0, end: 10))
        #expect(area.isCovered)
    }

    @Test func uncheckedStretchesOutsideItsSpanDontCount() {
        var area = region()
        area.isFollowed = true
        area.markUnchecked(TimeSpan(start: 4.5, end: 6))
        #expect(area.openUnchecked == [TimeSpan(start: 4.5, end: 5)])
        // Cut shorter, the stretch past its end no longer counts.
        area.setSpan(TimeSpan(start: 1, end: 4.4))
        #expect(area.openUnchecked.isEmpty)
    }

    @Test func lengtheningAFollowedAreaMarksWhatNothingFollowed() {
        var area = region()
        area.isFollowed = true
        area.keyframes = [BlurKeyframe(time: 2, box: area.box), BlurKeyframe(time: 4, box: area.box)]
        area.setSpan(TimeSpan(start: 0.5, end: 6))
        #expect(area.openUnchecked == [TimeSpan(start: 0.5, end: 1), TimeSpan(start: 5, end: 6)])
        // An area that stands still covers the same place wherever it lasts: nothing to mark.
        var still = region()
        still.setSpan(TimeSpan(start: 0, end: 8))
        #expect(still.openUnchecked.isEmpty)
    }

    @Test func noStrengthIsWeak() {
        var area = region()
        area.strength = 0
        #expect(area.pixelBlocks == 8)
        #expect(area.blurSteps == 10)
        area.strength = 1
        #expect(area.pixelBlocks == 4)
        area.strength = 7
        #expect(area.pixelBlocks == 4)
    }

    @Test func aFacesAreaCoversTheHeadAboveTheFeatures() {
        let face = NormalizedBox(x: 0.4, y: 0.3, width: 0.1, height: 0.1)
        let area = BlurRegion.area(aroundFace: face)
        #expect(area.width > face.width * 1.4)
        #expect(area.height > face.height * 1.6)
        #expect(area.y < face.y - 0.03, "the forehead and hair")
        #expect(area.y + area.height > face.y + face.height, "the chin")
        let made = BlurRegion(target: .recording(nil), span: TimeSpan(start: 0, end: 1), box: area, subject: .face)
        #expect(made.shape == .oval)
    }

    @Test func itReadsBackWholeAndLenient() throws {
        var area = region()
        area.style = .solid
        area.color = .yellow
        area.feather = 0.4
        area.isFollowed = true
        area.keyframes = [BlurKeyframe(time: 2, box: area.box, isSet: true)]
        area.markUnchecked(TimeSpan(start: 3, end: 4))
        let read = try JSONDecoder().decode(BlurRegion.self, from: JSONEncoder().encode(area))
        #expect(read.style == .solid && read.color == .yellow && read.isFollowed)
        #expect(read.keyframes.first?.isSet == true)
        #expect(read.openUnchecked == [TimeSpan(start: 3, end: 4)])
        // A style and a shape from a newer Cue read as the ones that still hide; a broken keyframe is left out alone.
        var json = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(area)) as? [String: Any])
        json["style"] = "emoji"
        json["shape"] = "star"
        json["keyframes"] = [["time": "soon"], ["time": 2, "box": [0.1, 0.1, 0.2, 0.2]]]
        let newer = try JSONDecoder().decode(BlurRegion.self, from: JSONSerialization.data(withJSONObject: json))
        #expect(newer.style == .pixelate)
        #expect(newer.shape == .rectangle)
        #expect(newer.keyframes.count == 1)
    }

    @Test func anEditSavedBeforeBlurAreasHasNone() throws {
        var json = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(EditFixtures.blank())) as? [String: Any])
        json["blurRegions"] = nil
        let edit = try JSONDecoder().decode(TakeEdit.self, from: JSONSerialization.data(withJSONObject: json))
        #expect(edit.blurRegions.isEmpty)
    }
}
