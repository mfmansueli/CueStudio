//
//  TransitionDrawingTests.swift
//  Cue StudioTests
//

import CoreImage
import Foundation
import Testing
@testable import Cue_Studio

/// The new transitions: each starts on the outgoing frame and ends on the incoming one, keeps the frame's size, and is the
/// same every time it's drawn; the duration a creator sets is kept within its range and old edits read as before.
@Suite("Transition drawing")
struct TransitionDrawingTests {
    private let extent = CGRect(x: 0, y: 0, width: 90, height: 160)
    private var red: CIImage { CIImage(color: CIColor(red: 0.8, green: 0.1, blue: 0.1)).cropped(to: extent) }
    private var blue: CIImage { CIImage(color: CIColor(red: 0.1, green: 0.2, blue: 0.8)).cropped(to: extent) }

    private func middle(_ image: CIImage) -> (red: Double, green: Double, blue: Double) {
        RenderedPixels(image).rgb(at: CGPoint(x: 45, y: 80))
    }

    @Test func eachGoesFromTheOutgoingToTheIncomingFrame() {
        for transition in [EditTransition.zoom, .blur, .flash, .push, .punch, .wipe] {
            let start = TransitionDrawing.draw(transition, from: red, to: blue, progress: 0)
            let end = TransitionDrawing.draw(transition, from: red, to: blue, progress: 1)
            #expect(start.extent == extent && end.extent == extent, "\(transition)")
            #expect(middle(start).red > 150 && middle(start).blue < 80, "\(transition) starts on the outgoing frame")
            #expect(middle(end).blue > 150 && middle(end).red < 80, "\(transition) ends on the incoming frame")
        }
    }

    @Test func theFlashBurnsBrighterThanEitherSide() {
        let peak = middle(TransitionDrawing.draw(.flash, from: red, to: blue, progress: 0.5))
        #expect(peak.red > 150 && peak.blue > 150)
    }

    @Test func thePushMovesTheWholePicture() {
        // Halfway: the outgoing side on the left, the incoming one on the right.
        let image = TransitionDrawing.draw(.push, from: red, to: blue, progress: 0.5)
        let pixels = RenderedPixels(image)
        #expect(pixels.rgb(at: CGPoint(x: 5, y: 80)).red > 150)
        #expect(pixels.rgb(at: CGPoint(x: 85, y: 80)).blue > 150)
    }

    @Test func theDurationIsTheCreatorsWithinItsRange() throws {
        var timeline = EditTimeline(sourceDuration: 10)
        timeline.split(atEdited: 5)
        timeline.setTransition(.zoom, atJoin: 1)
        #expect(TransitionWindow.windows(in: timeline).first?.halfDuration == EditTransition.zoom.duration / 2)
        timeline.setTransitionDuration(1.2, atJoin: 1)
        #expect(abs((TransitionWindow.windows(in: timeline).first?.halfDuration ?? 0) - 0.6) < 0.000_1)
        timeline.setTransitionDuration(9, atJoin: 1)
        #expect(abs((TransitionWindow.windows(in: timeline).first?.halfDuration ?? 0) - EditTransition.durationRange.upperBound / 2) < 0.000_1)
        let decoded = try JSONDecoder().decode(EditTimeline.self, from: JSONEncoder().encode(timeline))
        #expect(decoded.segments[1].transitionDuration == 9)
        // Saved before durations could be set: its own length.
        var segment = EditSegment(sourceStart: 0, sourceEnd: 1)
        segment.transitionDuration = nil
        #expect(try JSONDecoder().decode(EditSegment.self, from: JSONEncoder().encode(segment)).transitionDuration == nil)
    }

    @Test func aSplitMakesAHardCutOfItsOwnLength() {
        var timeline = EditTimeline(sourceDuration: 10)
        timeline.split(atEdited: 5)
        timeline.setTransition(.zoom, atJoin: 1)
        timeline.setTransitionDuration(1.2, atJoin: 1)
        // The clip after the join split again: the left part keeps the join's transition, the new seam is a plain cut.
        timeline.split(atEdited: 7)
        #expect(timeline.segments[1].transitionIn == .zoom && timeline.segments[1].transitionDuration == 1.2)
        #expect(timeline.segments[2].transitionIn == .hardCut && timeline.segments[2].transitionDuration == nil)
    }
}
