//
//  EditTimelinePutBackTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

/// Put back (D7): one removed stretch comes back where it was, alone, after the clip was moved, sped up or copied; with no
/// clip left around it, there is no place and the reason is said.
@Suite("Edit timeline put back")
struct EditTimelinePutBackTests {
    private let pause = TimeSpan(start: 2, end: 3)
    private let other = TimeSpan(start: 6, end: 7)

    /// A 10 s take with 2–3 and 6–7 removed.
    private func cut() -> EditTimeline {
        var timeline = EditTimeline(sourceDuration: 10)
        timeline.remove([pause, other])
        return timeline
    }

    @Test func aPausePutBackComesBackAloneAndTheOtherCutStays() throws {
        var timeline = cut()
        let places = timeline.putBackPlaces(for: pause, in: nil)
        #expect(places.count == 1)
        let place = try #require(places.first)
        #expect(abs(place.editedTime - 2) < 0.001)
        let done1 = timeline.putBack(pause, in: nil, at: place)
        #expect(done1)
        #expect(timeline.keptSpans == [TimeSpan(start: 0, end: 6), TimeSpan(start: 7, end: 10)])
        // Back: nothing left to put back, and the reason isn't a problem.
        #expect(timeline.putBackPlaces(for: pause, in: nil).isEmpty)
        #expect(timeline.putBackBlock(for: pause, in: nil) == .alreadyPlays)
    }

    @Test func aMovedClipDoesNotStopIt() throws {
        var timeline = cut()
        // 0–2 moved to the end: the montage plays 3–6, 7–10, 0–2.
        let done2 = timeline.moveSegment(from: 0, to: 2)
        #expect(done2)
        let places = timeline.putBackPlaces(for: pause, in: nil)
        // The two sides of one removal are one place: after 0–2, where it played.
        #expect(places.count == 1)
        let place = try #require(places.first)
        #expect(place.edge == .after)
        let done3 = timeline.putBack(pause, in: nil, at: place)
        #expect(done3)
        #expect(timeline.segments.map(\.span) == [TimeSpan(start: 3, end: 6), TimeSpan(start: 7, end: 10), TimeSpan(start: 0, end: 3)])
        #expect(timeline.putBackPlaces(for: pause, in: nil).isEmpty)
        // The other cut is untouched.
        #expect(!timeline.putBackPlaces(for: other, in: nil).isEmpty)
    }

    @Test func aSpeedChangeDoesNotStopIt() throws {
        var timeline = cut()
        let done4 = timeline.setSpeed(2, forSegmentAt: 1)
        #expect(done4)
        let place = try #require(timeline.putBackPlaces(for: pause, in: nil).first)
        let done5 = timeline.putBack(pause, in: nil, at: place)
        #expect(done5)
        // It plays at the speed of the clip it joins (0–2, normal speed), and the sped-up clip keeps its speed.
        #expect(abs(timeline.editedDuration - (3 + 3.0 / 2 + 3)) < 0.001)
        #expect(timeline.segments.contains { abs($0.speed - 2) < 0.001 && $0.span == TimeSpan(start: 3, end: 6) })
    }

    @Test func aCopiedClipIsTwoPlacesPutBackOneAtATime() throws {
        var timeline = cut()
        let first = try #require(timeline.segments.first?.id)
        let copied = timeline.duplicateSegment(id: first)
        let copy = try #require(copied)
        let places = timeline.putBackPlaces(for: pause, in: nil)
        #expect(Set(places.map(\.segmentID)) == [first, copy])
        let theCopy = try #require(places.first { $0.segmentID == copy })
        let before = timeline.editedDuration
        let done6 = timeline.putBack(pause, in: nil, at: theCopy)
        #expect(done6)
        #expect(abs(timeline.editedDuration - before - 1) < 0.001)
        // The original's place is still there.
        #expect(timeline.putBackPlaces(for: pause, in: nil).map(\.segmentID) == [first])
    }

    @Test func noClipAroundItIsAConflictWithItsReason() throws {
        var timeline = cut()
        timeline.split(atEdited: 1)
        // 0–1, 1–2, 3–6, 7–10 in a new order with 1–2 and 3–6 gone: nothing touches 2–3.
        let done7 = timeline.moveSegment(from: 3, to: 0)
        #expect(done7)
        let gone = timeline.segments.filter { $0.span == TimeSpan(start: 1, end: 2) || $0.span == TimeSpan(start: 3, end: 6) }
        for segment in gone {
            let removed = timeline.removeSegment(id: segment.id)
            #expect(removed)
        }
        #expect(timeline.putBackPlaces(for: pause, in: nil).isEmpty)
        #expect(timeline.putBackBlock(for: pause, in: nil) == .clipsGone)
        let unchanged = timeline
        let stale = EditTimeline.PutBackPlace(segmentID: try #require(timeline.segments.first?.id), edge: .after, editedTime: 0)
        let done8 = timeline.putBack(pause, in: nil, at: stale)
        #expect(!done8)
        #expect(timeline == unchanged)
    }

    @Test func aStretchPastATrimmedStartIsTrimmedOff() {
        var timeline = cut()
        timeline.trimStart(to: 4)
        #expect(timeline.putBackPlaces(for: pause, in: nil).isEmpty)
        #expect(timeline.putBackBlock(for: pause, in: nil) == .trimmedOff)
    }

    /// A pause at the very end of the take (the demo's last one): removing it moves the end; Put back moves it out again. Past an
    /// end the creator dragged in further, it stays trimmed off.
    @Test func aPauseRemovedAtTheEndComesBack() throws {
        var timeline = EditTimeline(sourceDuration: 10)
        let last = TimeSpan(start: 8.5, end: 10)
        timeline.remove([last])
        #expect(abs(timeline.trimEnd - 8.5) < 0.001)
        let place = try #require(timeline.putBackPlaces(for: last, in: nil).first)
        let back = timeline.putBack(last, in: nil, at: place)
        #expect(back)
        #expect(abs(timeline.editedDuration - 10) < 0.001)
        var dragged = EditTimeline(sourceDuration: 10)
        dragged.remove([last])
        dragged.trimEnd(to: 7)
        #expect(dragged.putBackPlaces(for: last, in: nil).isEmpty)
        #expect(dragged.putBackBlock(for: last, in: nil) == .trimmedOff)
    }

    @Test func aPauseRemovedAtTheStartComesBack() throws {
        var timeline = EditTimeline(sourceDuration: 10)
        let first = TimeSpan(start: 0, end: 1.2)
        timeline.remove([first])
        let place = try #require(timeline.putBackPlaces(for: first, in: nil).first)
        let back = timeline.putBack(first, in: nil, at: place)
        #expect(back)
        #expect(abs(timeline.editedDuration - 10) < 0.001)
    }
}
