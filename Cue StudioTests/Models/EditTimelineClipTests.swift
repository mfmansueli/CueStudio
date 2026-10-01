//
//  EditTimelineClipTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

@Suite("EditTimeline clips")
struct EditTimelineClipTests {
    /// 21.6 s split at 7.1 and 10.1: three clips, the middle one is "não, pera".
    private func threeClips() -> EditTimeline {
        var timeline = EditTimeline(sourceDuration: 21.6)
        timeline.split(atEdited: 7.1)
        timeline.split(atEdited: 10.1)
        return timeline
    }

    // MARK: - Trim by handles

    @Test func theLeftHandleMovesWhereTheClipStarts() {
        var timeline = threeClips()
        let last = timeline.segments[2].id
        let changed = timeline.trimSegment(id: last, edge: .start, toSource: 12)
        #expect(changed)
        #expect(timeline.segments[2].sourceStart == 12)
        #expect(abs(timeline.editedDuration - 19.7) < 0.000_1)
    }

    @Test func aHandleNeverRunsIntoTheNeighborInTheTake() {
        var timeline = threeClips()
        let middle = timeline.segments[1].id
        timeline.trimSegment(id: middle, edge: .start, toSource: 2)
        #expect(timeline.segments[1].sourceStart == 7.1)
        timeline.trimSegment(id: middle, edge: .end, toSource: 20)
        #expect(timeline.segments[1].sourceEnd == 10.1)
    }

    @Test func whatWasCutComesBackUpToTheNeighbor() {
        var timeline = threeClips()
        let middle = timeline.segments[1].id
        timeline.removeSegment(id: middle)
        let last = timeline.segments[1].id
        // The gap left by the deleted clip can be brought back from either side.
        timeline.trimSegment(id: last, edge: .start, toSource: 8)
        #expect(timeline.segments[1].sourceStart == 8)
        timeline.trimSegment(id: last, edge: .start, toSource: 0)
        #expect(timeline.segments[1].sourceStart == 7.1)
    }

    @Test func aClipKeepsAtLeastThreeTenths() {
        var timeline = threeClips()
        let first = timeline.segments[0].id
        timeline.trimSegment(id: first, edge: .end, toSource: -5)
        #expect(abs(timeline.segments[0].sourceLength - EditTimeline.minimumClipDuration) < 0.000_1)
        timeline.trimSegment(id: first, edge: .start, toSource: 50)
        #expect(abs(timeline.segments[0].sourceLength - EditTimeline.minimumClipDuration) < 0.000_1)
    }

    @Test func theEndsOfTheTakeBoundTheOuterHandles() {
        var timeline = threeClips()
        let first = timeline.segments[0].id
        let last = timeline.segments[2].id
        timeline.trimSegment(id: first, edge: .start, toSource: 3)
        timeline.trimSegment(id: first, edge: .start, toSource: -4)
        #expect(timeline.segments[0].sourceStart == 0)
        timeline.trimSegment(id: last, edge: .end, toSource: 40)
        #expect(timeline.segments[2].sourceEnd == 21.6)
    }

    @Test func nothingMovingIsNoChange() {
        var timeline = threeClips()
        let first = timeline.segments[0].id
        let atTheEdge = timeline.trimSegment(id: first, edge: .start, toSource: 0)
        let unknown = timeline.trimSegment(id: UUID(), edge: .start, toSource: 1)
        #expect(!atTheEdge)
        #expect(!unknown)
    }

    @Test func aFasterClipTrimsInItsRecordingsSeconds() {
        var timeline = threeClips()
        timeline.setSpeed(2, forSegmentAt: 2)
        let last = timeline.segments[2].id
        timeline.trimSegment(id: last, edge: .end, toSource: 19.6)
        #expect(abs(timeline.segments[2].duration - 4.75) < 0.000_1)
    }

    // MARK: - What a clip carries

    @Test func splittingKeepsTheClipsSoundAndZoom() {
        var timeline = EditTimeline(sourceDuration: 20)
        var clip = timeline.segments[0]
        clip.volume = 1.5
        clip.isMuted = true
        clip.keepsPitch = false
        clip.zoom = .pushIn
        clip.zoomAmount = 0.8
        timeline.replaceSegment(clip)
        timeline.split(atEdited: 10)
        let right = timeline.segments[1]
        #expect(right.volume == 1.5)
        #expect(right.isMuted)
        #expect(!right.keepsPitch)
        #expect(right.zoom == .pushIn)
        #expect(right.zoomAmount == 0.8)
        #expect(right.id != clip.id)
    }

    @Test func duplicatingKeepsTheClipsSound() throws {
        var timeline = EditTimeline(sourceDuration: 20)
        var clip = timeline.segments[0]
        clip.volume = 0.4
        timeline.replaceSegment(clip)
        let duplicated = timeline.duplicateSegment(id: clip.id)
        let copy = try #require(duplicated)
        #expect(timeline.segment(id: copy)?.volume == 0.4)
    }

    @Test func removingPausesKeepsTheClipsSound() {
        var timeline = EditTimeline(sourceDuration: 20)
        var clip = timeline.segments[0]
        clip.isMuted = true
        timeline.replaceSegment(clip)
        timeline.remove([TimeSpan(start: 5, end: 6)])
        #expect(timeline.segments.allSatisfy { $0.isMuted })
    }

    // MARK: - Saved before

    @Test func clipsSavedBeforeHaveFullSoundAndTheirOldZoom() throws {
        let json = """
        {"id":"6F9619FF-8B86-D011-B42D-00C04FC964FF","sourceStart":0,"sourceEnd":4,"speed":1,"zoom":"pushIn"}
        """
        let clip = try JSONDecoder().decode(EditSegment.self, from: Data(json.utf8))
        #expect(clip.volume == 1)
        #expect(!clip.isMuted)
        #expect(clip.keepsPitch)
        #expect(clip.zoomAmount == 0.4)
        let punched = try JSONDecoder().decode(EditSegment.self, from: Data(json.replacingOccurrences(of: "pushIn", with: "punchIn").utf8))
        #expect(punched.zoomAmount == 0.5)
    }

    @Test func clipSettingsSurviveSaving() throws {
        var clip = EditSegment(sourceStart: 1, sourceEnd: 3)
        clip.volume = 1.8
        clip.isMuted = true
        clip.keepsPitch = false
        clip.zoomAmount = 0.9
        let decoded = try JSONDecoder().decode(EditSegment.self, from: JSONEncoder().encode(clip))
        #expect(decoded == clip)
    }
}
