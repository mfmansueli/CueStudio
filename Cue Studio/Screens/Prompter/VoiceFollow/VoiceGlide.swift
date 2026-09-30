//
//  VoiceGlide.swift
//  Cue Studio
//

import Foundation

/// How quickly Voice Following's text catches up with where it should be
/// (`PrompterScrollEngine.glide`): quickly for the small steps of a reading followed word by word,
/// so the line being read doesn't trail the voice; smoothly for a bigger correction (a skipped
/// sentence, recognition catching up after a burst), so the eye can follow the text and never sees
/// it jump.
nonisolated struct VoiceGlide: Equatable, Sendable {
    /// Time to get about two thirds of the way, for a correction up to `smallDistance` lines.
    var small: TimeInterval = 0.2
    /// The same for a correction of `largeDistance` lines or more. Voice Following's single
    /// glide before it adapted.
    var large: TimeInterval = 0.35
    var smallDistance: Double = 0.5
    var largeDistance: Double = 2

    /// The glide time for a correction `distance` points long; in between the two sizes, in
    /// proportion.
    func time(forDistance distance: Double, lineHeight: Double) -> TimeInterval {
        guard lineHeight > 0, largeDistance > smallDistance else { return large }
        let lines = abs(distance) / lineHeight
        let share = min(1, max(0, (lines - smallDistance) / (largeDistance - smallDistance)))
        return small + (large - small) * share
    }
}
