//
//  EditTimelineSpeedTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

@Suite("EditTimeline speed")
struct EditTimelineSpeedTests {
    private func near(_ lhs: Double, _ rhs: Double) -> Bool { abs(lhs - rhs) < 0.000_1 }

    /// [A][B][C][D] from a 60 s take: cuts at 15, 30 and 45.
    private func fourPieces() -> EditTimeline {
        var timeline = EditTimeline(sourceDuration: 60)
        for cut in [15.0, 30, 45] { timeline.split(atEdited: cut) }
        return timeline
    }

    @Test func doubleSpeedHalvesTheEdit() {
        var timeline = EditTimeline(sourceDuration: 60)
        let changed = timeline.setSpeed(2)
        #expect(changed)
        #expect(near(timeline.editedDuration, 30))
        #expect(near(timeline.sourceTime(forEdited: 10), 20))
        #expect(timeline.editedTime(forSource: 20).map { near($0, 10) } == true)
        let again = timeline.setSpeed(2)
        #expect(!again)
    }

    @Test func oneSectionAtItsOwnSpeed() {
        var timeline = fourPieces()
        let changed = timeline.setSpeed(0.5, forSegmentAt: 1)
        #expect(changed)
        #expect(near(timeline.editedDuration, 75))
        #expect(near(timeline.editedStart(ofSegmentAt: 2), 45))
        #expect(near(timeline.sourceTime(forEdited: 25), 20))
        let spans = timeline.sourceSpans(forEdited: 15...25)
        #expect(spans.count == 1)
        #expect(near(spans[0].start, 15) && near(spans[0].end, 20))
    }

    @Test func splittingKeepsTheSpeed() {
        var timeline = EditTimeline(sourceDuration: 60)
        timeline.setSpeed(2)
        let split = timeline.split(atEdited: 10)
        #expect(split)
        #expect(timeline.segments.count == 2)
        #expect(near(timeline.segments[0].sourceEnd, 20))
        #expect(timeline.segments.allSatisfy { $0.speed == 2 })
        #expect(near(timeline.editedDuration, 30))
    }

    @Test func removingKeepsTheSpeedOfWhatStays() {
        var timeline = fourPieces()
        timeline.setSpeed(2, forSegmentAt: 1)
        let removed = timeline.removeEdited(16...18)
        #expect(removed)
        let sped = timeline.segments.filter { $0.speed == 2 }
        #expect(sped.count == 2)
        #expect(near(sped[0].sourceEnd, 17) && near(sped[1].sourceStart, 21))
    }

    @Test func aSpeedChangeIsASeamEvenWithNothingRemoved() {
        var timeline = fourPieces()
        #expect(timeline.continuousSpans == [TimeSpan(start: 0, end: 60)])
        timeline.setSpeed(1.5, forSegmentAt: 2)
        #expect(timeline.continuesFromPrevious(2))
        #expect(!timeline.isSeamless(2))
        #expect(timeline.continuousSpans.count == 3)
    }

    @Test func thePreviewStartsLaterInItsItemAtASlowerSpeed() {
        var timeline = EditTimeline(sourceDuration: 60)
        timeline.trimStart(to: 10)
        #expect(near(timeline.reachableLeadIn, 10))
        timeline.setSpeed(0.5)
        #expect(near(timeline.reachableLeadIn, 20))
        #expect(near(timeline.reachable.editedTime(forSource: 10) ?? -1, 20))
    }

    @Test func overlaysPinnedToTheRecordingFollowCutsAndSpeed() {
        var timeline = EditTimeline(sourceDuration: 60)
        let text = TimeSpan(start: 20, end: 23)
        #expect(timeline.editedSpan(forSource: text) == text)
        timeline.removeEdited(5...10)
        #expect(timeline.editedSpan(forSource: text) == TimeSpan(start: 15, end: 18))
        timeline.setSpeed(2)
        let sped = timeline.editedSpan(forSource: text)
        #expect(sped.map { near($0.start, 7.5) && near($0.end, 9) } == true)
        // Placed on the edit, pinned back to the recording.
        let placed = timeline.sourceSpan(forEdited: TimeSpan(start: 7.5, end: 9))
        #expect(near(placed.start, 20) && near(placed.end, 23))
    }

    @Test func anOverlayWhoseMomentIsCutDisappears() {
        var timeline = EditTimeline(sourceDuration: 60)
        timeline.removeEdited(20...30)
        #expect(timeline.editedSpan(forSource: TimeSpan(start: 22, end: 28)) == nil)
    }

    @Test func framesSnapAtTheSectionsSpeed() {
        var timeline = EditTimeline(sourceDuration: 60)
        timeline.setSpeed(2)
        let grid = FrameGrid(rate: 30)
        // 0.51 s of the edit is 1.02 s of the recording: the nearest frame is 1.0333 s (0.5167 s edited).
        #expect(near(grid.snapped(edited: 0.51, in: timeline), 31.0 / 30 / 2))
    }

    @Test func piecesSavedBeforeSpeedPlayAtOne() throws {
        let json = #"{"id":"6B1F2C3D-1111-2222-3333-444455556666","sourceStart":1,"sourceEnd":5}"#
        let segment = try JSONDecoder().decode(EditSegment.self, from: Data(json.utf8))
        #expect(segment.speed == 1)
        #expect(segment.duration == 4)
    }

    @Test func speedIsKeptInRange() {
        var timeline = EditTimeline(sourceDuration: 10)
        timeline.setSpeed(100)
        #expect(timeline.segments[0].speed == EditSegment.speedRange.upperBound)
        #expect(EditSegment.clampedSpeed(.nan) == 1)
    }

    @Test func presetsHaveShortLabels() {
        #expect(PlaybackSpeed.double.label == "2×")
        #expect(PlaybackSpeed.nearest(to: 1.3) == .oneAndAQuarter)
    }
}
