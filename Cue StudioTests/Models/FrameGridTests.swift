//
//  FrameGridTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

@Suite("FrameGrid")
struct FrameGridTests {
    private func near(_ a: TimeInterval, _ b: TimeInterval) -> Bool { abs(a - b) < 0.000_01 }

    @Test func snapsToTheNearestFrameAtTheFilesRate() {
        let thirty = FrameGrid(rate: 30)
        #expect(near(thirty.snapped(10.44), 313.0 / 30))
        #expect(near(thirty.frameDuration, 1.0 / 30))
        let sixty = FrameGrid(rate: 60)
        #expect(near(sixty.snapped(10.44), 626.0 / 60))
        // Not rounded to seconds, nor to hundredths.
        #expect(!near(thirty.snapped(10.44), 10.44))
        #expect(!near(thirty.snapped(10.44), 10))
    }

    @Test func aRateThatCantBeReadIsThirty() {
        #expect(FrameGrid(rate: 0).rate == 30)
        #expect(FrameGrid(rate: .nan).rate == 30)
        #expect(FrameGrid(rate: 29.97).rate == 29.97)
        #expect(FrameGrid(rate: 1_000).rate == 240)
    }

    @Test func theEndsOfASpanWinWhenNearer() {
        let grid = FrameGrid(rate: 30)
        // A recording 10.01 s long: its last frame starts at 10.0, but its end can still be reached.
        let recording = TimeSpan(start: 0, end: 10.01)
        #expect(near(grid.snapped(10.009, in: recording), 10.01))
        #expect(near(grid.snapped(10.004, in: recording), 10))
        #expect(near(grid.snapped(12, in: recording), 10.01))
        #expect(near(grid.snapped(-1, in: recording), 0))
    }

    @Test func editedTimesLandOnFramesInsideTheirPiece() {
        var timeline = EditTimeline(sourceDuration: 10)
        timeline.split(atEdited: 4)
        timeline.split(atEdited: 6)
        timeline.removeSegment(id: timeline.segments[1].id)
        let grid = FrameGrid(rate: 30)
        // Edited 5.01 plays 7.01 of the recording: its frame starts at 7.0, edited 5.0.
        #expect(near(grid.snapped(edited: 5.01, in: timeline), 5))
        #expect(near(grid.snapped(edited: 0.02, in: timeline), 1.0 / 30))
        #expect(near(grid.snapped(edited: 8, in: timeline), 8))
    }

    @Test func listsTheFramesInASpan() {
        let starts = FrameGrid(rate: 30).frameStarts(in: TimeSpan(start: 1, end: 1.1))
        #expect(starts.count == 4)
        #expect(near(starts.first ?? 0, 1))
        #expect(near(starts.last ?? 0, 1.1))
        #expect(FrameGrid(rate: 30).frameStarts(in: TimeSpan(start: 2, end: 2)).isEmpty)
    }
}
