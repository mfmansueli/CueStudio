//
//  QuickCreatorCompositionTests.swift
//  Cue StudioTests
//

import AVFoundation
import CoreGraphics
import CoreImage
import Foundation
import Testing
@testable import Cue_Studio

@Suite("Quick Creator composition")
struct QuickCreatorCompositionTests {
    @Test func stretchesAreAlsoCutWhereAVideoShows() {
        let duration = CMTime(seconds: 12, preferredTimescale: 600)
        let stretches = EditedComposition.stretches(for: [], media: [TimeSpan(start: 3, end: 5)], duration: duration)
        #expect(stretches.map(\.showsMedia) == [false, true, false])
        #expect(stretches.first?.range.start == .zero)
        #expect(stretches.last?.range.end == duration)
        for (earlier, later) in zip(stretches, stretches.dropFirst()) {
            #expect(earlier.range.end == later.range.start)
        }
        #expect(abs(stretches[1].range.start.seconds - 3) < 0.002)
        #expect(abs(stretches[1].range.end.seconds - 5) < 0.002)
    }

    @Test func aVideoAcrossADissolveSplitsItToo() {
        var timeline = EditTimeline(sourceDuration: 30)
        timeline.removeEdited(9...10)
        timeline.setTransition(.dissolve, atJoin: 1)
        let dissolves = TransitionWindow.windows(in: timeline)
        let duration = CMTime(seconds: timeline.editedDuration, preferredTimescale: 600)
        let stretches = EditedComposition.stretches(for: dissolves, media: [TimeSpan(start: 8, end: 9)], duration: duration)
        #expect(stretches.map { $0.dissolve != nil } == [false, false, true, true, false])
        #expect(stretches.map(\.showsMedia) == [false, true, true, false, false])
    }

    @Test func withoutMediaTheStretchesAreTheSame() {
        var timeline = EditTimeline(sourceDuration: 60)
        for cut in [10.0, 20] { timeline.split(atEdited: cut) }
        timeline.setTransition(.dissolve, atJoin: 1)
        let dissolves = TransitionWindow.windows(in: timeline)
        let duration = CMTime(seconds: 60, preferredTimescale: 600)
        let old = EditedComposition.instructionRanges(for: dissolves, duration: duration)
        let new = EditedComposition.stretches(for: dissolves, media: [], duration: duration)
        #expect(old.map(\.range) == new.map(\.range))
        #expect(new.allSatisfy { !$0.showsMedia })
    }

    @Test func speedChangesDipTheSoundAtTheirSeam() {
        var timeline = EditTimeline(sourceDuration: 20)
        timeline.split(atEdited: 10)
        #expect(EditedComposition.fades(for: timeline).isEmpty)
        timeline.setSpeed(2, forSegmentAt: 1)
        #expect(EditedComposition.fades(for: timeline).count == 2)
    }

    @MainActor
    @Test func textsScaleWithTheFrame() {
        var text = TextOverlay(role: .title, style: .clean, span: TimeSpan(start: 0, end: 1))
        text.text = "Hello"
        let small = TextOverlayRenderer.size(for: text, frameWidth: 402)
        let large = TextOverlayRenderer.size(for: text, frameWidth: 1080)
        #expect(small.width > 0 && small.height > 0)
        #expect(abs(large.width / small.width - 1080.0 / 402.0) < 0.15)
        text.text = " "
        #expect(TextOverlayRenderer.size(for: text, frameWidth: 402) == .zero)
    }

    @MainActor
    @Test func textsLandWhereTheyArePlaced() {
        var text = TextOverlay(role: .title, style: .clean, span: TimeSpan(start: 1, end: 2))
        text.text = "Hi"
        text.center = OverlayPoint(x: 0.5, y: 0.25)
        let overlays = TextOverlayRenderer.overlays([(text, TimeSpan(start: 1, end: 2))], frame: CGSize(width: 1080, height: 1920))
        #expect(overlays.count == 1)
        let overlay = overlays[0]
        let size = overlay.image.extent.size
        // Core Image's y is from the bottom: a quarter from the top is three quarters up.
        #expect(abs(overlay.origin.y + size.height / 2 - 1440) < 1)
        #expect(abs(overlay.origin.x + size.width / 2 - 540) < 1)
        #expect(overlay.isVisible(at: 1.5))
        #expect(!overlay.isVisible(at: 2.5))
    }
}
