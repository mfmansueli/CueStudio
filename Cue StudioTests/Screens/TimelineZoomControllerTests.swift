//
//  TimelineZoomControllerTests.swift
//  Cue StudioTests
//

import CoreGraphics
import Foundation
import Testing
@testable import Cue_Studio

/// The Trim timeline's zoom and scroll: glides keep their anchor, limits follow the take.
@MainActor
@Suite("TimelineZoomController")
struct TimelineZoomControllerTests {
    private let layout = TimelineLayout(timeline: EditTimeline(sourceDuration: 120), width: 340)

    private func makeController(frameRate: Double = 30) -> TimelineZoomController {
        let zoom = TimelineZoomController()
        zoom.configure(fitPointsPerSecond: layout.fitPointsPerSecond, frameRate: frameRate)
        return zoom
    }

    private func x(of time: TimeInterval, in zoom: TimelineZoomController) -> CGFloat {
        layout.zoomed(zoom.zoom, offset: zoom.offset).x(forStrip: time)
    }

    @Test func startsOnTheWholeTake() {
        let zoom = makeController()
        #expect(zoom.zoom == 1)
        #expect(zoom.offset == 0)
        #expect(!zoom.isZoomed)
        #expect(!zoom.isManual)
        #expect(zoom.hint(isRemovingPart: true) == nil)
    }

    @Test func aJumpKeepsTheAnchorWhereAsked() {
        let zoom = makeController()
        zoom.glide(to: 40, keeping: 60, fromX: 170, toX: 170, in: layout, animated: false)
        #expect(zoom.zoom == 40)
        #expect(zoom.targetZoom == 40)
        #expect(abs(x(of: 60, in: zoom) - 170) < 0.001)
        #expect(zoom.hint(isRemovingPart: true) == "Zoomed in · drag the red edges")
        #expect(zoom.hint(isRemovingPart: false) == "Zoomed in · pinch to zoom out")
    }

    @Test func aGlideArrivesWithTheAnchorInPlace() async throws {
        let zoom = makeController()
        zoom.glide(to: 16, keeping: 30, fromX: 100, toX: 170, in: layout, animated: true)
        #expect(zoom.targetZoom == 16)
        // The glide runs on frames; a busy machine delivers them late, so wait for it to arrive.
        let clock = ContinuousClock()
        let deadline = clock.now + TimelineZoomController.glideDuration * 20
        while abs(zoom.zoom - 16) >= 0.001, clock.now < deadline {
            try await Task.sleep(for: .milliseconds(20))
        }
        #expect(abs(zoom.zoom - 16) < 0.001)
        #expect(abs(x(of: 30, in: zoom) - 170) < 0.01)
    }

    @Test func theDeepestZoomIsFrameByFrame() {
        let zoom = makeController()
        zoom.glide(to: zoom.maximum, keeping: 60, fromX: 170, toX: 170, in: layout, animated: false)
        #expect(zoom.isFramePrecise)
        #expect(zoom.hint(isRemovingPart: true) == "Frame by frame · drag the red edges")
        #expect(zoom.hint(isRemovingPart: false) == "Frame by frame · pinch to zoom out")
        // Sixty frames a second go twice as deep.
        #expect(abs(makeController(frameRate: 60).maximum - 2 * zoom.maximum) < 0.001)
    }

    @Test func aZoomPastTheNewMaximumComesBackToIt() {
        let zoom = makeController()
        zoom.set(zoom: zoom.maximum, offset: 0)
        zoom.configure(fitPointsPerSecond: layout.fitPointsPerSecond * 4, frameRate: 30)
        #expect(abs(zoom.zoom - zoom.maximum) < 0.001)
    }

    @Test func stepsAreByHand() {
        let zoom = makeController()
        zoom.step(zoomingIn: true, keeping: 60, atX: 170, in: layout, animated: false)
        #expect(zoom.zoom == 1.5)
        #expect(zoom.isManual)
        #expect(abs(x(of: 60, in: zoom) - 170) < 0.001)
        zoom.step(zoomingIn: false, keeping: 60, atX: 170, in: layout, animated: false)
        #expect(zoom.zoom == 1)
        zoom.resumeAutomatic()
        #expect(!zoom.isManual)
    }

    @Test func panningStopsAGlideWhereItIs() {
        let zoom = makeController()
        zoom.glide(to: 40, keeping: 60, fromX: 170, toX: 170, in: layout, animated: true)
        zoom.pan(to: 50)
        #expect(zoom.offset == 50)
        #expect(zoom.targetZoom == zoom.zoom)
    }
}
