//
//  ZoomAnchorTests.swift
//  Cue StudioTests
//

import CoreGraphics
import Foundation
import Testing
@testable import Cue_Studio

/// How the zooms Cue makes grow (`ZoomAnchor`, `FaceZoomFocus`, `ZoomMoment`): toward one face it can trust, never switching person,
/// never cutting the head, never past what the recording's pixels allow; the creator's own zoom from the middle, as it was.
struct ZoomAnchorTests {
    /// Ten seconds of a recording, ten moments a second, with `faces` at each moment (by its index).
    private func analysis(_ faces: (Int) -> [NormalizedBox]) -> MotionAnalysis {
        var analysis = MotionAnalysis(duration: 10, width: 1080, height: 1920)
        analysis.subjects = (0..<100).map { SubjectSample(time: Double($0) / 10, faces: faces($0), bodies: []) }
        analysis.analyzedUntil = 10
        return analysis
    }

    private let face = NormalizedBox(center: CGPoint(x: 0.4, y: 0.3), width: 0.3, height: 0.17)

    @Test func oneSteadyFaceIsGrownToward() throws {
        let focus = try #require(FaceZoomFocus.of(analysis { _ in [face] }))
        #expect(abs(focus.center.x - 0.4) < 0.001)
        #expect(abs(focus.center.y - 0.3) < 0.001)
        // The head reaches above the face's box.
        #expect(focus.head.y < face.y)
        // A small face far behind (a poster) doesn't count as a second person.
        let poster = NormalizedBox(center: CGPoint(x: 0.85, y: 0.1), width: 0.05, height: 0.03)
        #expect(FaceZoomFocus.of(analysis { _ in [face, poster] }) != nil)
    }

    @Test func twoPeopleOrAnUncertainFaceGrowFromTheMiddle() {
        let other = NormalizedBox(center: CGPoint(x: 0.75, y: 0.35), width: 0.25, height: 0.14)
        #expect(FaceZoomFocus.of(analysis { _ in [face, other] }) == nil, "Two people: no one is chosen")
        #expect(FaceZoomFocus.of(analysis { $0 % 2 == 0 ? [face] : [] }) == nil, "Found half the time")
        let wandering = analysis { index in [NormalizedBox(center: CGPoint(x: 0.2 + Double(index) * 0.006, y: 0.3), width: 0.3, height: 0.17)] }
        #expect(FaceZoomFocus.of(wandering) == nil, "Moves across the frame")
        #expect(FaceZoomFocus.of(analysis { _ in [] }) == nil)
    }

    /// A horizontal 1080p video cropped to 9:16 has about 607 pixels across: 1.12× at most. A 1080p take: 2×.
    @Test func lowResolutionHoldsTheZoomBack() {
        let horizontal = CGSize(width: 1920, height: 1080)
        let cropped = FramePlacement(uprightSize: horizontal, crop: CropMath.crop(in: horizontal, aspect: 9.0 / 16, offset: 0))
        let limited = ZoomAnchor.make(placement: cropped, face: nil, followsFace: false, at: 0)
        #expect(abs(limited.resolutionLimit - 607.5 / ZoomAnchor.minimumPixels) < 0.01)
        #expect(limited.zoom(section: 1.25, sectionIsManual: false, combined: 1.25).scale < 1.13)

        let take = CGSize(width: 1080, height: 1920)
        let full = ZoomAnchor.make(placement: FramePlacement(uprightSize: take, crop: CGRect(origin: .zero, size: take)), face: nil, followsFace: false, at: 0)
        #expect(abs(full.resolutionLimit - 2) < 0.001)
        #expect(full.zoom(section: 1, sectionIsManual: false, combined: 1.45).scale == 1.45)
    }

    @Test func theHeadStaysInTheFrame() {
        var anchor = ZoomAnchor()
        anchor.pivot = OverlayPoint(x: 0.5, y: 0.2)
        anchor.head = CGRect(x: 0.35, y: 0.05, width: 0.3, height: 0.3)
        // The head's top at 0.05, 0.15 above the pivot: 0.2 / 0.15 = 1.33× brings it to the frame's top.
        #expect(abs(anchor.headLimit(around: anchor.pivot) - 0.2 / 0.15) < 0.000_1)
        #expect(abs(anchor.zoom(section: 1, sectionIsManual: false, combined: 1.45).scale - 0.2 / 0.15) < 0.000_1)
        // A head already past an edge can't be helped and doesn't hold the zoom back.
        anchor.head = CGRect(x: 0.35, y: -0.1, width: 0.3, height: 0.4)
        #expect(anchor.headLimit(around: anchor.pivot) > 1.45)
    }

    /// The creator's own zoom stays from the middle and is never held back; Punch in on cuts' grows toward the face.
    @Test func theCreatorsZoomStaysAsItWas() {
        var anchor = ZoomAnchor()
        anchor.pivot = OverlayPoint(x: 0.4, y: 0.3)
        anchor.head = CGRect(x: 0.2, y: 0.1, width: 0.4, height: 0.4)
        anchor.resolutionLimit = 1.1
        let manual = ZoomWindow(zoom: .punchIn, start: 0, duration: 4, amount: 1)
        let mine = ZoomMoment.at(1, section: manual, phrases: [], anchor: anchor)
        #expect(abs(mine.scale - 1.3) < 0.000_1)
        #expect(mine.pivot == .center)
        var punched = manual
        punched.punchesInOnCut = true
        let cues = ZoomMoment.at(1, section: punched, phrases: [], anchor: anchor)
        #expect(abs(cues.scale - 1.1) < 0.000_1)
        #expect(cues.pivot == anchor.pivot)
        // A phrase zoom over the creator's zoom adds nothing past the limits.
        let phrase = PhraseZoomWindow(span: TimeSpan(start: 0, end: 4), scale: 1.25)
        #expect(abs(ZoomMoment.at(2, section: manual, phrases: [phrase], anchor: anchor).scale - 1.3) < 0.000_1)
    }

    /// Grown toward the face, the face stays where it is on the frame while everything else grows around it (so the handles
    /// over the preview follow what the compositor draws).
    @Test func theFaceStaysPutWhileItZooms() throws {
        let take = CGSize(width: 1080, height: 1920)
        var placement = FramePlacement(uprightSize: take, crop: CGRect(origin: .zero, size: take))
        let focus = try #require(FaceZoomFocus.of(analysis { _ in [face] }))
        placement.zoomAnchor = ZoomAnchor.make(placement: placement, face: focus, followsFace: false, at: 5)
        var segment = EditSegment(sourceStart: 0, sourceEnd: 10, zoom: .punchIn)
        segment.zoomAmount = 0.5
        segment.punchesInOnCut = true
        let zoomed = placement.moment(of: segment, startingAt: 0, at: 5)
        #expect(zoomed.zoom > 1.1)
        let shown = zoomed.videoPoint(for: focus.center, at: 5)
        #expect(abs(shown.x - 0.4) < 0.001 && abs(shown.y - 0.3) < 0.001)
        let corner = zoomed.videoPoint(for: CGPoint(x: 0.9, y: 0.9), at: 5)
        #expect(corner.x > 0.9 && corner.y > 0.9)
        // Under Follow face the frame already follows the face: from the middle.
        let following = ZoomAnchor.make(placement: placement, face: focus, followsFace: true, at: 5)
        #expect(following.pivot == .center && following.head == nil)
    }
}
