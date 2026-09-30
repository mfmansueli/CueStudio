//
//  EditTimelineMontageTests.swift
//  Cue StudioTests
//

import AVFoundation
import Foundation
import Testing
@testable import Cue_Studio

/// Arranged timelines: copies, a new order and other recordings, played as arranged; handles that
/// trim one piece; removals that act on the pieces they cover; and what is pinned to a piece.
@Suite("Edit timeline montage")
struct EditTimelineMontageTests {
    private let other = UUID()

    /// A 60 s take cut at 20 and 40.
    private func threePieces() -> EditTimeline {
        var timeline = EditTimeline(sourceDuration: 60)
        timeline.split(atEdited: 20)
        timeline.split(atEdited: 40)
        return timeline
    }

    // MARK: - Old timelines

    @Test func aTimelineSavedBeforeMontagesIsTheTakesOwn() throws {
        let json = #"""
            {"sourceDuration": 30, "segments": [
                {"id": "\#(UUID().uuidString)", "sourceStart": 10, "sourceEnd": 20},
                {"id": "\#(UUID().uuidString)", "sourceStart": 0, "sourceEnd": 5}
            ]}
            """#
        let timeline = try JSONDecoder().decode(EditTimeline.self, from: Data(json.utf8))
        #expect(!timeline.isArranged)
        // Put back in the recording's order, as before.
        #expect(timeline.keptSpans == [TimeSpan(start: 0, end: 5), TimeSpan(start: 10, end: 20)])
    }

    // MARK: - Copies and order

    @Test func aCopyPlaysRightAfterItsSection() throws {
        var timeline = threePieces()
        let middle = timeline.segments[1].id
        let duplicated = timeline.duplicateSegment(id: middle)
        let copy = try #require(duplicated)
        #expect(timeline.isArranged)
        #expect(timeline.segments.count == 4)
        #expect(timeline.segments[2].id == copy)
        #expect(timeline.segments[2].span == timeline.segments[1].span)
        #expect(timeline.segments[2].transitionIn == .hardCut)
        #expect(timeline.editedDuration == 80)
    }

    @Test func movingASectionKeepsTheFirstCutHard() {
        var timeline = threePieces()
        timeline.setTransition(.dissolve, atJoin: 1)
        let moved = timeline.moveSegment(from: 1, to: 0)
        #expect(moved)
        #expect(timeline.keptSpans.first == TimeSpan(start: 20, end: 40))
        #expect(timeline.transition(atJoin: 0) == .hardCut)
        #expect(timeline.segments[0].transitionIn == .hardCut)
        let movedInPlace = timeline.moveSegment(from: 1, to: 1)
        #expect(!movedInPlace)
    }

    @Test func anArrangedTimelineKeepsItsOrderThroughSaving() throws {
        var timeline = threePieces()
        timeline.moveSegment(from: 2, to: 0)
        timeline.insertClip(source: other, duration: 12)
        let decoded = try JSONDecoder().decode(EditTimeline.self, from: JSONEncoder().encode(timeline))
        #expect(decoded == timeline)
        #expect(decoded.keptSpans.first == TimeSpan(start: 40, end: 60))
        #expect(decoded.segments.last?.sourceID == other)
    }

    @Test func anotherRecordingJoinsWithItsOwnLength() throws {
        var timeline = EditTimeline(sourceDuration: 60)
        let inserted = timeline.insertClip(source: other, duration: 12, span: TimeSpan(start: 2, end: 30))
        let id = try #require(inserted)
        #expect(timeline.segment(id: id)?.span == TimeSpan(start: 2, end: 12))
        #expect(timeline.duration(ofSource: other) == 12)
        #expect(timeline.editedDuration == 70)
        #expect(!timeline.continuesFromPrevious(1))
        // Too short to be a section.
        let tooShort = timeline.insertClip(source: UUID(), duration: 0.05)
        #expect(tooShort == nil)
    }

    // MARK: - Handles and removals

    @Test func arrangedHandlesTrimOnlyTheFirstAndLastSection() {
        var timeline = threePieces()
        timeline.moveSegment(from: 2, to: 0)
        // Past the first cut, the handle stops at the first section's end.
        timeline.trimStart(to: 70)
        #expect(timeline.segments.count == 3)
        #expect(abs(timeline.segments[0].sourceStart - (60 - EditTimeline.minimumDuration)) < 0.001)
        timeline.insertClip(source: other, duration: 12, span: TimeSpan(start: 0, end: 6))
        timeline.trimEnd(to: 100)
        #expect(timeline.segments.last?.sourceEnd == 12)
        #expect(timeline.reachable.segments.last?.sourceEnd == 12)
    }

    @Test func removingAPartTakesItOutOfThatSectionOnly() throws {
        var timeline = EditTimeline(sourceDuration: 30)
        let duplicated = timeline.duplicateSegment(id: timeline.segments[0].id)
        try #require(duplicated != nil)
        // 5 to 10 s of the first copy; the second copy still plays them.
        let removed = timeline.removeEdited(5...10)
        #expect(removed)
        #expect(timeline.editedDuration == 55)
        #expect(timeline.keptSpans == [TimeSpan(start: 0, end: 5), TimeSpan(start: 10, end: 30), TimeSpan(start: 0, end: 30)])
    }

    @Test func cleanUpTakesAMomentOfTheTakeOutWhereverItPlaysButNeverOtherRecordings() throws {
        var timeline = EditTimeline(sourceDuration: 30)
        let duplicated = timeline.duplicateSegment(id: timeline.segments[0].id)
        try #require(duplicated != nil)
        timeline.insertClip(source: other, duration: 10)
        let removed = timeline.remove([TimeSpan(start: 5, end: 6)])
        #expect(removed)
        #expect(timeline.editedDuration == 29 + 29 + 10)
        #expect(timeline.segments.last?.span == TimeSpan(start: 0, end: 10))
    }

    // MARK: - Mapping

    @Test func theTakesSecondsMapToTheFirstSectionThatPlaysThem() throws {
        var timeline = threePieces()
        let duplicated = timeline.duplicateSegment(id: timeline.segments[0].id)
        try #require(duplicated != nil)
        // 5 s of the take plays at 5 s and again at 25 s: the first wins.
        #expect(timeline.editedTime(forSource: 5) == 5)
        #expect(timeline.editedTime(forSource: 5, in: other) == nil)
    }

    @Test func somethingPinnedToASectionFollowsIt() throws {
        var timeline = threePieces()
        let last = timeline.segments[2]
        let pinned = timeline.anchoredSpan(forEdited: TimeSpan(start: 45, end: 47))
        #expect(pinned.anchor.segmentID == last.id)
        #expect(pinned.span == TimeSpan(start: 45, end: 47))
        timeline.moveSegment(from: 2, to: 0)
        #expect(timeline.editedSpan(forSource: pinned.span, anchoredTo: pinned.anchor) == TimeSpan(start: 5, end: 7))
    }

    @Test func aCopyShowsWhatIsPinnedToItAndNotToTheOriginal() throws {
        var timeline = EditTimeline(sourceDuration: 30)
        let original = timeline.segments[0].id
        let duplicated = timeline.duplicateSegment(id: original)
        let copy = try #require(duplicated)
        let span = TimeSpan(start: 4, end: 6)
        #expect(timeline.editedSpan(forSource: span, anchoredTo: ClipAnchor(segmentID: original)) == TimeSpan(start: 4, end: 6))
        #expect(timeline.editedSpan(forSource: span, anchoredTo: ClipAnchor(segmentID: copy)) == TimeSpan(start: 34, end: 36))
    }

    @Test func afterASplitThePinFindsThePieceThatHoldsIt() {
        var timeline = threePieces()
        timeline.moveSegment(from: 0, to: 2)
        let anchor = ClipAnchor(segmentID: timeline.segments[2].id)
        // The section (0–20 s of the take, now last) is split: the pin's piece loses 10–20 s.
        timeline.split(atEdited: 50)
        #expect(timeline.editedSpan(forSource: TimeSpan(start: 12, end: 14), anchoredTo: anchor) == TimeSpan(start: 52, end: 54))
    }

    @Test func thePlayheadStaysOnTheSameMomentWhenASectionMoves() {
        let before = threePieces()
        var after = before
        after.moveSegment(from: 2, to: 0)
        // 45 s (5 s into the last section) is now 5 s in.
        #expect(after.editedTime(matching: 45, in: before) == 5)
    }

    @Test func aDissolveIntoAnotherRecordingIsLimitedByThatRecording() {
        var timeline = EditTimeline(sourceDuration: 30)
        timeline.trimEnd(to: 20)
        timeline.insertClip(source: other, duration: 10, span: TimeSpan(start: 0.2, end: 10))
        timeline.setTransition(.dissolve, atJoin: 1)
        let windows = TransitionWindow.windows(in: timeline)
        #expect(windows.count == 1)
        #expect(windows[0].incomingSource == other)
        #expect(windows[0].outgoingSource == nil)
        // Only 0.2 s of the other recording before its start: the dissolve is that short on each side.
        #expect(windows[0].halfDuration <= 0.2 + 0.000_1)
    }

    @Test func sectionsOfOtherRecordingsSplitTheCompositionsStretches() {
        var timeline = EditTimeline(sourceDuration: 10)
        timeline.insertClip(source: other, duration: 5)
        let stretches = EditedComposition.splitBySource(
            [(range: CMTimeRange(start: .zero, end: CMTime(seconds: 15, preferredTimescale: 600)), dissolve: nil, showsMedia: false)],
            in: timeline
        )
        #expect(stretches.map { $0.range.end.seconds } == [10, 15])
    }
}
