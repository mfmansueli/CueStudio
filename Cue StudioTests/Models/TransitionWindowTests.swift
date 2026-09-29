//
//  TransitionWindowTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

@Suite("TransitionWindow")
struct TransitionWindowTests {
    private func near(_ a: TimeInterval, _ b: TimeInterval) -> Bool { abs(a - b) < 0.000_1 }

    /// A 30 s take cut at 10 and 20, with 10–12 removed: [0,10] [12,20] [20,30].
    private func threePieces() -> EditTimeline {
        var timeline = EditTimeline(sourceDuration: 30)
        timeline.split(atEdited: 20)
        timeline.remove([TimeSpan(start: 10, end: 12)])
        return timeline
    }

    @Test func hardCutsHaveNoWindow() {
        #expect(TransitionWindow.windows(in: threePieces()).isEmpty)
        #expect(TransitionWindow.windows(in: EditTimeline(sourceDuration: 30)).isEmpty)
    }

    @Test func aWindowIsCenteredOnItsCutAndKeepsTheLength() {
        var timeline = threePieces()
        timeline.setTransition(.dissolve, atJoin: 1)
        timeline.setTransition(.fade, atJoin: 2)
        let windows = TransitionWindow.windows(in: timeline)
        #expect(windows.count == 2)
        let dissolve = windows[0]
        #expect(dissolve.transition == .dissolve)
        #expect(dissolve.join == 1)
        #expect(near(dissolve.cut, 10))
        #expect(near(dissolve.start, 10 - EditTransition.dissolve.duration / 2))
        #expect(near(dissolve.end, 10 + EditTransition.dissolve.duration / 2))
        #expect(dissolve.outgoingEnd == 10)
        #expect(dissolve.incomingStart == 12)
        let fade = windows[1]
        #expect(near(fade.cut, 18))
        #expect(near(fade.halfDuration, EditTransition.fade.duration / 2))
        // Transitions never change how long the edit plays.
        #expect(timeline.editedDuration == 28)
    }

    @Test func progressAndBlackness() {
        var timeline = threePieces()
        timeline.setTransition(.fade, atJoin: 1)
        let fade = TransitionWindow.windows(in: timeline)[0]
        #expect(fade.progress(at: fade.start) == 0)
        #expect(near(fade.progress(at: fade.cut), 0.5))
        #expect(fade.progress(at: fade.end + 1) == 1)
        #expect(fade.blackness(at: fade.cut) == 1)
        #expect(near(fade.blackness(at: fade.cut - fade.halfDuration / 2), 0.5))
        #expect(fade.blackness(at: fade.start - 0.1) == 0)
        #expect(fade.blackness(at: fade.end + 0.1) == 0)
    }

    @Test func shortPiecesGetShorterWindowsThatNeverOverlap() {
        // [0,10] [10,10.3] [10.3,30]: the middle piece is 0.3 s with a transition on each side.
        var timeline = EditTimeline(sourceDuration: 30)
        timeline.split(atEdited: 10)
        timeline.split(atEdited: 10.3)
        timeline.setTransition(.fade, atJoin: 1)
        timeline.setTransition(.fade, atJoin: 2)
        let windows = TransitionWindow.windows(in: timeline)
        #expect(windows.count == 2)
        #expect(windows[0].end <= windows[1].start + 0.000_1)
        #expect(windows.allSatisfy { $0.halfDuration <= 0.15 - TransitionWindow.margin + 0.000_1 })
    }

    @Test func aDissolvesOtherSidesAreAlwaysInTheRecording() {
        // The blend shows the outgoing piece running on past its end and the incoming one from
        // before its start: both are real frames of the recording, even around a removed part.
        var timeline = threePieces()
        timeline.setTransition(.dissolve, atJoin: 1)
        timeline.setTransition(.dissolve, atJoin: 2)
        for window in TransitionWindow.windows(in: timeline) {
            #expect(window.incomingStart - window.halfDuration >= 0)
            #expect(window.outgoingEnd + window.halfDuration <= timeline.sourceDuration)
        }
    }

    @Test func tooShortToShowStaysAHardCut() {
        var timeline = EditTimeline(sourceDuration: 30)
        timeline.split(atEdited: 10)
        timeline.split(atEdited: 10.12)
        let changed = timeline.setTransition(.fade, atJoin: 1)
        #expect(changed)
        // The 0.12 s piece leaves no room: less than `shortest` would show.
        #expect(TransitionWindow.windows(in: timeline).isEmpty)
    }
}
