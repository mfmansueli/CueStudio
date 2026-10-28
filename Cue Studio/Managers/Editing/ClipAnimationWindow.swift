//
//  ClipAnimationWindow.swift
//  Cue Studio
//

import Foundation

/// A clip's Animation where it plays in the edit: its way in over its first moments, its way out over its last.
nonisolated struct ClipAnimationWindow: Hashable, Sendable {
    /// Edited seconds where the clip starts, and how long it plays.
    let start: TimeInterval
    let duration: TimeInterval
    let entrance: ClipAnimation?
    let exit: ClipAnimation?

    /// How long each side lasts: as chosen, but no more than the clip has (half each when it has both).
    private var lengths: (entrance: TimeInterval, exit: TimeInterval) {
        let room = entrance != nil && exit != nil ? duration / 2 : duration
        return (min(entrance?.duration ?? 0, room), min(exit?.duration ?? 0, room))
    }

    /// What the picture is at `time` (edited seconds) while it comes in or goes out; nil the rest of the clip.
    func state(at time: TimeInterval) -> ClipAnimationFrame? {
        let lengths = lengths
        let elapsed = time - start
        if let entrance, elapsed < lengths.entrance {
            return ClipAnimation.frame(entrance.style, isIn: true, elapsed: elapsed, length: lengths.entrance)
        }
        let left = start + duration - time
        if let exit, left < lengths.exit {
            return ClipAnimation.frame(exit.style, isIn: false, elapsed: left, length: lengths.exit)
        }
        return nil
    }
}
