//
//  MusicClipTimelineTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

/// `MusicClip.following`: a sound effect stays on the moment of the video it was put on when the timeline changes; music keeps
/// its place in the edit.
@Suite("Music clip · following the timeline")
struct MusicClipTimelineTests {
    private func effect(at start: TimeInterval) -> MusicClip {
        var clip = MusicClip(fileName: "ding.m4a", title: "Ding", fileDuration: 1, start: start, length: 1)
        clip.effect = .ding
        return clip
    }

    private func music(at start: TimeInterval) -> MusicClip {
        MusicClip(fileName: "m.m4a", title: "Morning loop", fileDuration: 60, start: start, length: 20)
    }

    @Test func aCutBeforeAnEffectBringsItEarlierAndMusicStays() {
        let old = EditTimeline(sourceDuration: 60)
        var new = old
        let removed = new.remove([TimeSpan(start: 5, end: 10)])
        #expect(removed)
        let clips = MusicClip.following([effect(at: 30), music(at: 30)], from: old, to: new)
        #expect(abs(clips[0].start - 25) < 0.000_1)
        #expect(clips[1].start == 30)
    }

    @Test func aMovedClipTakesItsEffectAlong() {
        var old = EditTimeline(sourceDuration: 60)
        old.split(atEdited: 20)
        old.split(atEdited: 40)
        var new = old
        // The middle piece (20–40) plays first: an effect at 25 s now plays at 5 s.
        let moved = new.moveSegment(from: 1, to: 0)
        #expect(moved)
        let clips = MusicClip.following([effect(at: 25), music(at: 25)], from: old, to: new)
        #expect(abs(clips[0].start - 5) < 0.000_1)
        #expect(clips[1].start == 25)
    }

    @Test func anEffectNeverPlaysPastTheEnd() {
        let old = EditTimeline(sourceDuration: 60)
        var new = old
        let removed = new.remove([TimeSpan(start: 30, end: 60)])
        #expect(removed)
        let clips = MusicClip.following([effect(at: 59.5)], from: old, to: new)
        #expect(clips[0].start >= 0)
        #expect(clips[0].start + clips[0].length <= new.editedDuration + 0.000_1)
    }
}
