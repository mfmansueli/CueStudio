//
//  EditTimelineTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

@Suite("EditTimeline")
struct EditTimelineTests {
    private func spans(_ timeline: EditTimeline) -> [[TimeInterval]] {
        timeline.keptSpans.map { [$0.start, $0.end] }
    }

    /// [A][B][C][D] from a 60 s take: cuts at 15, 30 and 45.
    private func fourPieces() -> EditTimeline {
        var timeline = EditTimeline(sourceDuration: 60)
        for cut in [15.0, 30, 45] { timeline.split(atEdited: cut) }
        return timeline
    }

    // MARK: - Whole

    @Test func startsAsTheWholeRecording() {
        let timeline = EditTimeline(sourceDuration: 11)
        #expect(spans(timeline) == [[0, 11]])
        #expect(timeline.editedDuration == 11)
        #expect(timeline.isWhole)
    }

    // MARK: - Trim

    @Test func trimMovesTheOuterEndsOnly() {
        var timeline = EditTimeline(sourceDuration: 11)
        timeline.trimStart(to: 2)
        timeline.trimEnd(to: 9)
        #expect(spans(timeline) == [[2, 9]])
        #expect(timeline.editedDuration == 7)
        #expect(timeline.head == TimeSpan(start: 0, end: 2))
        #expect(timeline.tail == TimeSpan(start: 9, end: 11))
        #expect(!timeline.isWhole)
    }

    @Test func handlesNeverCross() {
        var timeline = EditTimeline(sourceDuration: 11)
        timeline.trimStart(to: 20)
        #expect(abs(timeline.trimStart - (11 - EditTimeline.minimumDuration)) < 0.000_1)
        timeline.trimEnd(to: -5)
        #expect(timeline.trimEnd > timeline.trimStart)
        #expect(abs(timeline.editedDuration - EditTimeline.minimumDuration) < 0.000_1)
    }

    @Test func trimsStayInsideTheRecording() {
        var timeline = EditTimeline(sourceDuration: 11)
        timeline.trimStart(to: -3)
        timeline.trimEnd(to: 40)
        #expect(timeline.isWhole)
    }

    @Test func trimDownToAFewFrames() {
        var timeline = EditTimeline(sourceDuration: 5)
        timeline.trimStart(to: 2)
        timeline.trimEnd(to: 2.1)
        #expect(abs(timeline.editedDuration - 0.1) < 0.000_1)
    }

    @Test func withSeveralPiecesTheHandlesTrimTheFirstAndLast() {
        var timeline = fourPieces()
        timeline.trimStart(to: 20)
        #expect(abs(timeline.trimStart - (15 - EditTimeline.minimumDuration)) < 0.000_1)
        timeline.trimEnd(to: 50)
        #expect(spans(timeline).last == [45, 50])
        #expect(timeline.segments.count == 4)
    }

    // MARK: - Cut

    @Test func cutMakesTwoRealPieces() {
        var timeline = EditTimeline(sourceDuration: 11)
        let done = timeline.split(atEdited: 5.32)
        #expect(done)
        #expect(spans(timeline) == [[0, 5.32], [5.32, 11]])
        #expect(timeline.editedDuration == 11)
        #expect(timeline.continuesFromPrevious(1))
    }

    @Test func cutsAtTheEdgesOrOnAnotherCutAreRefused() {
        var timeline = EditTimeline(sourceDuration: 11)
        let results = [0, 0.05, 11, 5, 5, 5.05].map { timeline.split(atEdited: $0) }
        #expect(results == [false, false, false, true, false, false])
        #expect(timeline.segments.count == 2)
    }

    @Test func cutsWorkAfterRemovals() {
        var timeline = fourPieces()
        timeline.removeSegment(id: timeline.segments[1].id)
        // Edited 20 is 5 s into the third piece, which starts at 30 in the recording.
        let done = timeline.split(atEdited: 20)
        #expect(done)
        #expect(spans(timeline) == [[0, 15], [30, 35], [35, 45], [45, 60]])
    }

    @Test func aOneSecondVideoCanBeCutAndTrimmed() {
        var timeline = EditTimeline(sourceDuration: 1)
        let done = timeline.split(atEdited: 0.5)
        #expect(done)
        timeline.trimStart(to: 0.45)
        #expect(abs(timeline.trimStart - 0.4) < 0.000_1)
        #expect(timeline.segments.allSatisfy { $0.duration >= EditTimeline.minimumDuration - 0.000_1 })
    }

    // MARK: - Remove

    @Test func removingAPieceTakesItOutOfTheEdit() {
        var timeline = EditTimeline(sourceDuration: 60)
        timeline.split(atEdited: 20)
        timeline.split(atEdited: 30)
        let done = timeline.removeSegment(id: timeline.segments[1].id)
        #expect(done)
        #expect(spans(timeline) == [[0, 20], [30, 60]])
        #expect(timeline.editedDuration == 50)
        #expect(!timeline.continuesFromPrevious(1))
    }

    @Test func removingBAndDLeavesAAndC() {
        var timeline = fourPieces()
        let b = timeline.segments[1].id, d = timeline.segments[3].id
        timeline.removeSegment(id: b)
        timeline.removeSegment(id: d)
        #expect(spans(timeline) == [[0, 15], [30, 45]])
        #expect(timeline.editedDuration == 30)
        // D was last, so the end handle now sits where C ends and can bring D back.
        #expect(timeline.tail == TimeSpan(start: 45, end: 60))
    }

    @Test func removingTheFirstPieceMovesTheStartHandle() {
        var timeline = fourPieces()
        timeline.removeSegment(id: timeline.segments[0].id)
        #expect(timeline.trimStart == 15)
        #expect(timeline.head == TimeSpan(start: 0, end: 15))
        timeline.trimStart(to: 0)
        #expect(spans(timeline).first == [0, 30])
    }

    @Test func theLastPieceCanNeverBeRemoved() {
        var timeline = fourPieces()
        for segment in timeline.segments.dropLast() { timeline.removeSegment(id: segment.id) }
        #expect(timeline.segments.count == 1)
        let refused = timeline.removeSegment(id: timeline.segments[0].id)
        #expect(!refused)
        #expect(timeline.editedDuration == 15)
    }

    // MARK: - Mapping

    @Test func editedAndSourceTimesMapBothWays() {
        var timeline = fourPieces()
        timeline.removeSegment(id: timeline.segments[1].id)
        #expect(timeline.editedTime(forSource: 10) == 10)
        #expect(timeline.editedTime(forSource: 20) == nil)
        #expect(timeline.editedTime(forSource: 31) == 16)
        #expect(timeline.editedTime(forSource: 60) == 45)
        #expect(timeline.sourceTime(forEdited: 16) == 31)
        #expect(timeline.sourceTime(forEdited: 15) == 30)
        #expect(timeline.segmentIndex(atEdited: 15) == 1)
        #expect(timeline.segmentIndex(atEdited: 45) == 2)
        #expect(timeline.editedStart(ofSegmentAt: 2) == 30)
    }

    @Test func thePlayheadFollowsTheSameMomentThroughAnEdit() {
        let before = fourPieces()
        var after = before
        after.removeSegment(id: after.segments[0].id)
        // 20 s in was 5 s into B; B now starts the edit.
        #expect(after.editedTime(matching: 20, in: before) == 5)
        // Inside the removed piece: where the edit picks up after it.
        #expect(after.editedTime(matching: 7, in: before) == 0)
    }

    @Test func movingAHandlePastThePlayheadTakesItAlong() {
        var before = EditTimeline(sourceDuration: 11)
        before.trimEnd(to: 10.5)
        var after = before
        after.trimEnd(to: 9)
        #expect(after.editedTime(matching: 10.2, in: before) == 9)
        var start = EditTimeline(sourceDuration: 11)
        start.trimStart(to: 3)
        #expect(start.editedTime(matching: 2, in: EditTimeline(sourceDuration: 11)) == 0)
    }

    // MARK: - Clean Up

    @Test func removingSpansCutsThemOutOfEveryPiece() {
        var timeline = EditTimeline(sourceDuration: 60)
        let done = timeline.remove([TimeSpan(start: 10, end: 12), TimeSpan(start: 30, end: 31)])
        #expect(done)
        #expect(spans(timeline) == [[0, 10], [12, 30], [31, 60]])
        #expect(timeline.editedDuration == 57)
        #expect(timeline.isRemoved(TimeSpan(start: 10, end: 12)))
        #expect(!timeline.isRemoved(TimeSpan(start: 9, end: 11)))
    }

    @Test func removingEverythingIsRefused() {
        var timeline = EditTimeline(sourceDuration: 10)
        let refused = timeline.remove([TimeSpan(start: 0, end: 10)])
        #expect(!refused)
        #expect(timeline.isWhole)
    }

    @Test func restoringClosesTheSeamsButKeepsHandCuts() {
        var timeline = EditTimeline(sourceDuration: 60)
        timeline.split(atEdited: 40)
        timeline.remove([TimeSpan(start: 10, end: 12)])
        #expect(timeline.segments.count == 3)
        timeline.restore([TimeSpan(start: 10, end: 12)])
        #expect(spans(timeline) == [[0, 40], [40, 60]])
    }

    @Test func restoringNeverReachesPastTheHandles() {
        var timeline = EditTimeline(sourceDuration: 60)
        timeline.trimStart(to: 20)
        timeline.restore([TimeSpan(start: 10, end: 12)])
        #expect(spans(timeline) == [[20, 60]])
    }

    // MARK: - Preview

    @Test func reachableGrowsTheEndsToTheWholeRecording() {
        var timeline = fourPieces()
        timeline.removeSegment(id: timeline.segments[1].id)
        timeline.trimStart(to: 5)
        timeline.trimEnd(to: 50)
        #expect(spans(timeline.reachable) == [[0, 15], [30, 45], [45, 60]])
        // The cut at 45 removed nothing, so no seam there.
        #expect(timeline.reachable.continuousSpans == [TimeSpan(start: 0, end: 15), TimeSpan(start: 30, end: 60)])
    }

    @Test func fittingToTheFilesLength() {
        var timeline = EditTimeline(sourceDuration: 64)
        #expect(timeline.fitted(toSourceDuration: 64.0004) == timeline)
        #expect(timeline.fitted(toSourceDuration: 64.4).trimEnd == 64.4)
        timeline.trimEnd(to: 60)
        #expect(timeline.fitted(toSourceDuration: 64.4).trimEnd == 60)
        #expect(timeline.fitted(toSourceDuration: 50).trimEnd == 50)
    }

    // MARK: - Files

    @Test func roundTrips() throws {
        var timeline = fourPieces()
        timeline.removeSegment(id: timeline.segments[2].id)
        let decoded = try JSONDecoder().decode(EditTimeline.self, from: JSONEncoder().encode(timeline))
        #expect(decoded == timeline)
    }

    @Test func aDamagedFileStillMakesAValidTimeline() throws {
        let json = """
        {"sourceDuration": 10, "segments": [
          {"id": "\(UUID().uuidString)", "sourceStart": 4, "sourceEnd": 20},
          {"id": "\(UUID().uuidString)", "sourceStart": 2, "sourceEnd": 5},
          {"id": "\(UUID().uuidString)", "sourceStart": 7, "sourceEnd": 7}
        ]}
        """
        let timeline = try JSONDecoder().decode(EditTimeline.self, from: Data(json.utf8))
        #expect(spans(timeline) == [[2, 5], [5, 10]])
        let empty = try JSONDecoder().decode(EditTimeline.self, from: Data(#"{"sourceDuration": 10, "segments": []}"#.utf8))
        #expect(empty.isWhole)
    }

    // MARK: - Long takes

    @Test func aFiveMinuteTakeWithManyCuts() {
        var timeline = EditTimeline(sourceDuration: 300)
        for cut in stride(from: 6.0, to: 300, by: 6) { timeline.split(atEdited: cut) }
        #expect(timeline.segments.count == 50)
        for segment in timeline.segments.enumerated().filter({ $0.offset.isMultiple(of: 2) }).map(\.element) {
            timeline.removeSegment(id: segment.id)
        }
        #expect(timeline.segments.count == 25)
        #expect(abs(timeline.editedDuration - 150) < 0.000_1)
        #expect(timeline.sourceTime(forEdited: 7) == 19)
    }
}
