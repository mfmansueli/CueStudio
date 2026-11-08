//
//  PreviewMotionHold.swift
//  Cue Studio
//

import Foundation
import os

/// The editor's preview showing the picked text, graphic, photo or video whole while it is paused (owner, canvas 2 F15,
/// 07/11/2026): with the playhead in its way in (a Pop's first frame) or its way out (the end of In and out), the preview draws
/// it as it is between them, so the creator sees what they style without the playhead jumping past the animation. Playing,
/// Preview and the export draw the motion as it is: only what is built for the editor's preview reads this
/// (`EditedComposition.Options.showsPickedWhole`), and the player lets go of it before it plays (`QuickEditPlayer`).
///
/// Read by the compositor at each frame (not part of the composition), so pausing and playing never rebuild the preview.
nonisolated final class PreviewMotionHold: Sendable {
    struct Hold: Hashable, Sendable {
        /// The text's or the photo's or video's id.
        let id: UUID
        /// Seconds into the item where it shows whole: its way in has ended and its way out hasn't begun.
        let whole: ClosedRange<TimeInterval>
    }

    static let shared = PreviewMotionHold()

    private let current = OSAllocatedUnfairLock<Hold?>(initialState: nil)

    var hold: Hold? { current.withLock { $0 } }

    /// Holds `hold` (nil: nothing); true when that changed what is held.
    @discardableResult
    func set(_ hold: Hold?) -> Bool {
        current.withLock { held in
            guard held != hold else { return false }
            held = hold
            return true
        }
    }

    /// `local` seconds into the item `id`, brought into its whole part while it is held.
    func local(_ local: TimeInterval, of id: UUID?) -> TimeInterval {
        guard let id, let hold, hold.id == id else { return local }
        return min(max(local, hold.whole.lowerBound), hold.whole.upperBound)
    }

    /// Where an item that shows for `length` seconds is whole: after a Motion's way in (and before In and out's way out), or a
    /// moving text effect's; nil when nothing hides or shrinks it (no Motion, a slow zoom, keyframes alone).
    static func wholePart(animation: OverlayAnimation?, effect: TextEffect?, length: TimeInterval) -> ClosedRange<TimeInterval>? {
        guard length > 0 else { return nil }
        if let animation {
            guard animation.preset != .gentleZoom else { return nil }
            let entrance = min(animation.duration, max(0.05, length / 2))
            let exit = animation.preset == .inAndOut ? entrance : 0
            return part(from: entrance, to: length - exit, length: length)
        }
        if let effect, effect.isAnimated {
            let timing = TextEffectChoreography.timing(effect, length: length)
            return part(from: timing.entrance, to: length - timing.exit, length: length)
        }
        return nil
    }

    /// From `start` to `end`; on an item too short for both, the moment between its way in and its way out.
    private static func part(from start: TimeInterval, to end: TimeInterval, length: TimeInterval) -> ClosedRange<TimeInterval> {
        guard end >= start else {
            let middle = min(max((start + end) / 2, 0), length)
            return middle...middle
        }
        return min(start, length)...min(end, length)
    }
}
