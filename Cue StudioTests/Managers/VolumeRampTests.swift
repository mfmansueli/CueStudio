//
//  VolumeRampTests.swift
//  Cue StudioTests
//

import AVFoundation
import Foundation
import Testing
@testable import Cue_Studio

/// The sound's volume changes (`EditedComposition.levels`) and how they go on the composition's clock (`VolumeRamp`): never two
/// at once, which AVFoundation answers by stopping the app (a clip's sound Fade out crashed the editor twice on the iPhone,
/// 28/10/2026), and each where it was meant.
@Suite("Volume ramps on the clock")
struct VolumeRampTests {
    /// Always the same "random" edits, so a failure can be run again.
    private struct Seeded: RandomNumberGenerator {
        var state: UInt64
        mutating func next() -> UInt64 {
            state &+= 0x9E37_79B9_7F4A_7C15
            var mixed = state
            mixed = (mixed ^ (mixed >> 30)) &* 0xBF58_476D_1CE4_E5B9
            mixed = (mixed ^ (mixed >> 27)) &* 0x94D0_49BB_1331_11EB
            return mixed ^ (mixed >> 31)
        }
    }

    private func overlaps(_ fades: [EditedComposition.Fade]) -> Bool {
        zip(fades, fades.dropFirst()).contains { $1.start < $0.start + $0.duration - 0.000_000_1 }
    }

    private func overlaps(_ ramps: [VolumeRamp]) -> Bool {
        zip(ramps, ramps.dropFirst()).contains { $1.range.start < $0.range.end }
    }

    /// What crashed: a clip louder than the one before it, straight after it (no ramp up from silence), its sound fading out as
    /// far as the slider goes (the clip's length to the tenth below: 4.0 s of 4.005 s). The fade out started 5 ms into the short
    /// ramp up to the clip's volume, inside it, which AVFoundation answers by ending the app (two ramps starting together don't:
    /// the later replaces the other). The fade out now waits for that ramp.
    @Test func aFadeOutOverTheWholeClipWaitsForTheRampToItsVolume() {
        var timeline = EditTimeline(sourceDuration: 10.005)
        timeline.split(atEdited: 6)
        var louder = timeline.segments[1]
        louder.volume = 1.75
        louder.soundFadeOut = 4
        timeline.replaceSegment(louder)
        let fades = EditedComposition.levels(for: timeline) { _ in true }
        #expect(!overlaps(fades))
        #expect(fades.contains { $0.start == 6 && $0.fromVolume == 1 && $0.toVolume == 1.75 })
        let fadeOut = fades.last
        #expect(fadeOut?.toVolume == 0 && abs((fadeOut?.start ?? 0) + (fadeOut?.duration ?? 0) - 10.005) < 0.000_1)
        #expect((fadeOut?.start ?? 0) >= 6 + EditedComposition.cutFade - 0.000_1)
        VolumeRamp.apply(VolumeRamp.scheduled(fades), to: AVMutableAudioMixInputParameters())
    }

    /// Edits with every sound change at once: cuts, removed and moved clips, speeds, volumes, mutes, transitions and fades.
    @Test func noEditEverPutsTwoRampsAtOnce() {
        var generator = Seeded(state: 28_10_2026)
        for _ in 0..<3_000 {
            var timeline = EditTimeline(sourceDuration: Double.random(in: 3...40, using: &generator))
            for _ in 0..<Int.random(in: 0...5, using: &generator) {
                timeline.split(atEdited: Double.random(in: 0.2...(timeline.editedDuration - 0.2), using: &generator))
            }
            if timeline.segments.count > 2, Bool.random(using: &generator) { timeline.removeSegment(id: timeline.segments[1].id) }
            if timeline.segments.count > 2, Bool.random(using: &generator) { timeline.moveSegment(from: 0, to: timeline.segments.count - 1) }
            for index in timeline.segments.indices {
                var clip = timeline.segments[index]
                if Bool.random(using: &generator) { clip.soundFadeIn = Double.random(in: 0...5, using: &generator) }
                if Bool.random(using: &generator) { clip.soundFadeOut = Double.random(in: 0...5, using: &generator) }
                if Int.random(in: 0...2, using: &generator) == 0 { clip.volume = Double.random(in: 0...2, using: &generator) }
                if Int.random(in: 0...5, using: &generator) == 0 { clip.isMuted = true }
                timeline.replaceSegment(clip)
                if Int.random(in: 0...3, using: &generator) == 0 {
                    timeline.setSpeed(Double.random(in: 0.5...3, using: &generator), forSegmentAt: index)
                }
                if index > 0, Int.random(in: 0...2, using: &generator) == 0 {
                    timeline.setTransition(EditTransition.allCases.randomElement(using: &generator) ?? .fade, atJoin: index)
                }
            }
            let fades = EditedComposition.levels(for: timeline) { _ in true }
            #expect(!overlaps(fades), "\(timeline.segments)")
            let ramps = VolumeRamp.scheduled(fades)
            #expect(!overlaps(ramps))
            // The same ramps on AVFoundation: two at once would stop the tests here.
            VolumeRamp.apply(ramps, to: AVMutableAudioMixInputParameters())
        }
    }

    @Test func eachRampKeepsItsPlace() {
        let fades = [
            EditedComposition.Fade(start: 0, duration: 0, fromVolume: 1, toVolume: 1),
            EditedComposition.Fade(start: 2, duration: 1.5, fromVolume: 1, toVolume: 0),
            EditedComposition.Fade(start: 3.5, duration: 0.05, fromVolume: 0, toVolume: 0.5),
        ]
        let ramps = VolumeRamp.scheduled(fades)
        #expect(ramps.map(\.range.start.value) == [0, 1_200, 2_100])
        #expect(ramps.map(\.range.duration.value) == [0, 900, 30])
        #expect(ramps.map(\.to) == [1, 0, 0.5])
    }

    /// Should two changes ever overlap again, the later one waits on the clock instead of stopping the app.
    @Test func aChangeThatWouldOverlapWaitsForTheOneBefore() {
        let ramps = VolumeRamp.scheduled([
            EditedComposition.Fade(start: 1, duration: 0.5, fromVolume: 1, toVolume: 1.5),
            EditedComposition.Fade(start: 1.005, duration: 2, fromVolume: 1.5, toVolume: 0),
            EditedComposition.Fade(start: 1.2, duration: 0, fromVolume: 0, toVolume: 0),
        ])
        #expect(!overlaps(ramps))
        #expect(ramps[1].range == CMTimeRange(start: CMTime(value: 900, timescale: 600), end: CMTime(value: 1_803, timescale: 600)))
        #expect(ramps[2].range.start == ramps[1].range.end)
        VolumeRamp.apply(ramps, to: AVMutableAudioMixInputParameters())
    }

    @Test func theMusicStartsAtItsFirstLevelAndRampsBetweenItsPoints() {
        let points = [
            MusicEnvelope.Point(time: 0, volume: 0.2), MusicEnvelope.Point(time: 0, volume: 0.2),
            MusicEnvelope.Point(time: 4, volume: 1), MusicEnvelope.Point(time: 9, volume: 0),
        ]
        #expect(EditedComposition.musicLevels(points) == [
            EditedComposition.Fade(start: 0, duration: 0, fromVolume: 0.2, toVolume: 0.2),
            EditedComposition.Fade(start: 0, duration: 4, fromVolume: 0.2, toVolume: 1),
            EditedComposition.Fade(start: 4, duration: 5, fromVolume: 1, toVolume: 0),
        ])
        #expect(EditedComposition.musicLevels([]).isEmpty)
    }
}
