//
//  EditedCompositionTests.swift
//  Cue StudioTests
//

import CoreMedia
import Foundation
import Testing
@testable import Cue_Studio

@Suite("EditedComposition")
struct EditedCompositionTests {
    @Test func soundDipsOnlyWhereSomethingWasRemoved() {
        var timeline = EditTimeline(sourceDuration: 60)
        timeline.split(atEdited: 10)
        timeline.split(atEdited: 20)
        timeline.split(atEdited: 30)
        // Pieces [0,10] [10,20] [20,30] [30,60]; removing [10,20] leaves one real seam at edited 10.
        timeline.removeSegment(id: timeline.segments[1].id)
        let fades = EditedComposition.fades(for: timeline)
        let length = EditedComposition.cutFade
        #expect(fades == [
            EditedComposition.Fade(start: 10 - length, duration: length, fromVolume: 1, toVolume: 0),
            EditedComposition.Fade(start: 10, duration: length, fromVolume: 0, toVolume: 1),
        ])
    }

    @Test func anUncutTakeHasNoFades() {
        #expect(EditedComposition.fades(for: EditTimeline(sourceDuration: 30)).isEmpty)
    }

    @Test func fadesFitInsideTinyPieces() {
        var timeline = EditTimeline(sourceDuration: 1)
        timeline.split(atEdited: 0.3)
        timeline.split(atEdited: 0.315)
        timeline.split(atEdited: 0.6)
        timeline.remove([TimeSpan(start: 0.4, end: 0.5)])
        for fade in EditedComposition.fades(for: timeline) {
            #expect(fade.duration <= EditedComposition.cutFade)
            #expect(fade.start >= 0)
        }
    }

    // MARK: - Clip volume

    private func clipAt(_ volume: Double, muted: Bool = false, in timeline: inout EditTimeline, index: Int) {
        var clip = timeline.segments[index]
        clip.volume = volume
        clip.isMuted = muted
        timeline.replaceSegment(clip)
    }

    @Test func eachClipPlaysAtItsVolume() {
        var timeline = EditTimeline(sourceDuration: 30)
        timeline.split(atEdited: 10)
        clipAt(0.5, in: &timeline, index: 1)
        let length = EditedComposition.cutFade
        // The two clips run on from each other: a quick ramp to the second one's level.
        #expect(EditedComposition.levels(for: timeline) { _ in true } == [
            EditedComposition.Fade(start: 0, duration: 0, fromVolume: 1, toVolume: 1),
            EditedComposition.Fade(start: 10, duration: length, fromVolume: 1, toVolume: 0.5),
        ])
    }

    @Test func aMutedClipIsSilentAndTheDipsFollowTheLevel() {
        var timeline = EditTimeline(sourceDuration: 30)
        timeline.split(atEdited: 10)
        timeline.split(atEdited: 20)
        timeline.removeSegment(id: timeline.segments[1].id)
        clipAt(1.8, muted: true, in: &timeline, index: 1)
        let levels = EditedComposition.levels(for: timeline) { _ in true }
        #expect(levels.contains { $0.start == 10 && $0.fromVolume == 0 && $0.toVolume == 0 })
        clipAt(1.8, in: &timeline, index: 1)
        let louder = EditedComposition.levels(for: timeline) { _ in true }
        #expect(louder.contains { $0.start == 10 && $0.toVolume == 1.8 })
    }

    @Test func clipsOnAnotherTrackAreSilentOnThisOne() {
        var timeline = EditTimeline(sourceDuration: 30)
        timeline.split(atEdited: 10)
        let other = timeline.segments[1].id
        let levels = EditedComposition.levels(for: timeline) { $0.id != other }
        #expect(levels.last?.toVolume == 0)
    }

    @Test func fullVolumeEverywhereAddsNothingToTheDips() {
        var timeline = EditTimeline(sourceDuration: 30)
        timeline.split(atEdited: 10)
        #expect(EditedComposition.levels(for: timeline) { _ in true }.isEmpty)
    }

    // MARK: - Transitions

    @Test func aFadeTakesTheSoundDownAndBackAtItsCut() {
        var timeline = EditTimeline(sourceDuration: 60)
        timeline.split(atEdited: 10)
        timeline.setTransition(.fade, atJoin: 1)
        let half = EditTransition.fade.duration / 2
        // A cut that removed nothing has no click to hide: only the fade's own ramp.
        #expect(EditedComposition.fades(for: timeline) == [
            EditedComposition.Fade(start: 10 - half, duration: half, fromVolume: 1, toVolume: 0),
            EditedComposition.Fade(start: 10, duration: half, fromVolume: 0, toVolume: 1),
        ])
    }

    @Test func aDissolveKeepsTheShortDipOfAHardCut() {
        var timeline = EditTimeline(sourceDuration: 60)
        timeline.split(atEdited: 10)
        timeline.split(atEdited: 20)
        timeline.removeSegment(id: timeline.segments[1].id)
        timeline.setTransition(.dissolve, atJoin: 1)
        let length = EditedComposition.cutFade
        #expect(EditedComposition.fades(for: timeline) == [
            EditedComposition.Fade(start: 10 - length, duration: length, fromVolume: 1, toVolume: 0),
            EditedComposition.Fade(start: 10, duration: length, fromVolume: 0, toVolume: 1),
        ])
    }

    @Test func dissolvesGetTheirOwnStretchesWithNoGaps() {
        var timeline = EditTimeline(sourceDuration: 60)
        for cut in [10.0, 20, 30] { timeline.split(atEdited: cut) }
        timeline.setTransition(.dissolve, atJoin: 1)
        timeline.setTransition(.fade, atJoin: 2)
        timeline.setTransition(.dissolve, atJoin: 3)
        let dissolves = TransitionWindow.windows(in: timeline).filter { $0.transition == .dissolve }
        let duration = CMTime(seconds: 60, preferredTimescale: 600)
        let ranges = EditedComposition.instructionRanges(for: dissolves, duration: duration)
        #expect(ranges.map { $0.dissolve?.join } == [nil, 1, nil, 3, nil])
        #expect(ranges.first?.range.start == .zero)
        #expect(ranges.last?.range.end == duration)
        for (earlier, later) in zip(ranges, ranges.dropFirst()) {
            #expect(earlier.range.end == later.range.start)
        }
        #expect(abs(ranges[1].range.start.seconds - (10 - EditTransition.dissolve.duration / 2)) < 0.002)
    }

    @Test func withoutDissolvesOneStretchCoversTheEdit() {
        let duration = CMTime(seconds: 12, preferredTimescale: 600)
        let ranges = EditedComposition.instructionRanges(for: [], duration: duration)
        #expect(ranges.count == 1)
        #expect(ranges[0].range == CMTimeRange(start: .zero, duration: duration))
        #expect(ranges[0].dissolve == nil)
    }
}
