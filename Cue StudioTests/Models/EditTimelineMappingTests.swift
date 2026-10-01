//
//  EditTimelineMappingTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

@Suite("EditTimeline mapping")
struct EditTimelineMappingTests {
    /// 21.6 s with "não, pera" (7.1–10.1) cut out.
    private func withoutTheMistake() -> EditTimeline {
        var timeline = EditTimeline(sourceDuration: 21.6)
        timeline.cutRange(7.1, 10.1)
        return timeline
    }

    @Test func momentsThatPlayMapStraight() {
        let timeline = withoutTheMistake()
        #expect(timeline.sourceToEdited(5, mode: .exact) == 5)
        #expect(abs((timeline.sourceToEdited(12.4, mode: .exact) ?? 0) - 9.4) < 0.000_1)
        #expect(abs(timeline.editedToSource(9.4) - 12.4) < 0.000_1)
    }

    @Test func aCutMomentMapsForwardOrBack() {
        let timeline = withoutTheMistake()
        #expect(timeline.sourceToEdited(8, mode: .exact) == nil)
        #expect(abs((timeline.sourceToEdited(8, mode: .forward) ?? 0) - 7.1) < 0.000_1)
        #expect(abs((timeline.sourceToEdited(8, mode: .backward) ?? 0) - 7.1) < 0.000_1)
    }

    @Test func nothingBeforeOrAfterIsNil() {
        var timeline = EditTimeline(sourceDuration: 21.6)
        timeline.trimStart(to: 2)
        timeline.trimEnd(to: 20)
        #expect(timeline.sourceToEdited(1, mode: .backward) == nil)
        #expect(timeline.sourceToEdited(1, mode: .forward) == 0)
        #expect(timeline.sourceToEdited(21, mode: .forward) == nil)
        #expect(abs((timeline.sourceToEdited(21, mode: .backward) ?? 0) - 18) < 0.000_1)
    }

    @Test func speedChangesTheEditedTimes() {
        var timeline = EditTimeline(sourceDuration: 20)
        timeline.setSpeed(2, forSegmentAt: 0)
        #expect(timeline.sourceToEdited(10, mode: .exact) == 5)
        #expect(timeline.editedToSource(5) == 10)
    }

    @Test func aLineInACutPartIsHiddenNotLost() {
        let timeline = withoutTheMistake()
        // "Primeiro: o pastel do… não, pera." was said in the cut part: it doesn't show.
        #expect(timeline.span(7.1, 9.0) == nil)
        // The line after it still shows, moved up by the cut.
        let line = timeline.span(10.1, 12.4)
        #expect(abs((line?.lowerBound ?? 0) - 7.1) < 0.000_1)
        #expect(abs((line?.upperBound ?? 0) - 9.4) < 0.000_1)
    }

    @Test func aLinePartlyCutShowsWhatsLeft() {
        let timeline = withoutTheMistake()
        let line = timeline.span(5.2, 8)
        #expect(line?.lowerBound == 5.2)
        #expect(abs((line?.upperBound ?? 0) - 7.1) < 0.000_1)
    }

    @Test func cutRangeTakesAPartOut() {
        var timeline = EditTimeline(sourceDuration: 21.6)
        let cut = timeline.cutRange(16.32, 17.68)
        #expect(cut)
        #expect(timeline.segments.count == 2)
        #expect(abs(timeline.editedDuration - (21.6 - 1.36)) < 0.000_1)
        let nothing = timeline.cutRange(5, 5)
        #expect(!nothing)
    }
}
