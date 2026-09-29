//
//  TransitionWindow.swift
//  Cue Studio
//

import Foundation

/// A transition placed on the edited video: centered on its cut, as long as the transition asks
/// for when both sections have room, and the parts of the recording it blends. The length never
/// changes: the edit plays exactly as long with or without transitions. Pure, so the preview, the
/// export and the tests read the same numbers.
nonisolated struct TransitionWindow: Hashable, Sendable {
    /// Room left on each side of a section, so two windows (or a window and the sound's dip at a
    /// hard cut) never overlap.
    static let margin: TimeInterval = 0.02
    /// Shorter than this, the cut stays hard.
    static let shortest: TimeInterval = 0.1

    let transition: EditTransition
    /// Index of the incoming piece in the timeline.
    let join: Int
    /// Edited seconds where the incoming piece starts.
    let cut: TimeInterval
    /// It runs from `cut - halfDuration` to `cut + halfDuration`.
    let halfDuration: TimeInterval
    /// Where the outgoing piece ends in the recording: a dissolve keeps it running past that.
    let outgoingEnd: TimeInterval
    /// Where the incoming piece starts in the recording: a dissolve shows it from before that.
    let incomingStart: TimeInterval
    /// Speeds of the two pieces: the other side of the cut plays at its own piece's speed.
    var outgoingSpeed: Double = 1
    var incomingSpeed: Double = 1

    var start: TimeInterval { cut - halfDuration }
    var end: TimeInterval { cut + halfDuration }

    /// 0 at the start of the window, 1 at its end.
    func progress(at time: TimeInterval) -> Double {
        guard halfDuration > 0 else { return time < cut ? 0 : 1 }
        return min(max(0, (time - start) / (2 * halfDuration)), 1)
    }

    /// How dark a fade is at `time`: 0 outside it, 1 on the cut.
    func blackness(at time: TimeInterval) -> Double {
        guard transition == .fade, halfDuration > 0 else { return 0 }
        return max(0, 1 - abs(time - cut) / halfDuration)
    }

    /// How far the incoming piece has slid in at `time`: 0 before the window, 1 after it.
    func slideProgress(at time: TimeInterval) -> Double {
        guard transition == .slide else { return time < cut ? 0 : 1 }
        let linear = progress(at: time)
        // Ease in and out, so the slide starts and lands softly.
        return linear * linear * (3 - 2 * linear)
    }

    /// Every seam that isn't a hard cut, in order. A dissolve (or a slide) needs the recording on both sides of
    /// its cut (the outgoing piece running on, the incoming one from before its start), so near the
    /// start or the end of the recording it gets shorter; when there's no room at all, it stays a
    /// hard cut.
    static func windows(in timeline: EditTimeline) -> [TransitionWindow] {
        let segments = timeline.segments
        var windows: [TransitionWindow] = []
        var cut: TimeInterval = 0
        for index in segments.indices {
            defer { cut += segments[index].duration }
            let transition = timeline.transition(atJoin: index)
            guard transition != .hardCut else { continue }
            let outgoing = segments[index - 1]
            let incoming = segments[index]
            var half = min(transition.duration / 2, outgoing.duration / 2 - margin, incoming.duration / 2 - margin)
            if transition.showsBothSides {
                half = min(half, (timeline.sourceDuration - outgoing.sourceEnd) / outgoing.speed, incoming.sourceStart / incoming.speed)
            }
            guard 2 * half >= shortest - 0.000_1 else { continue }
            windows.append(TransitionWindow(
                transition: transition, join: index, cut: cut, halfDuration: half,
                outgoingEnd: outgoing.sourceEnd, incomingStart: incoming.sourceStart,
                outgoingSpeed: outgoing.speed, incomingSpeed: incoming.speed
            ))
        }
        return windows
    }
}
