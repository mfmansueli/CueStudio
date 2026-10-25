//
//  MediaRun.swift
//  Cue Studio
//

import Foundation

/// How photos and videos picked together go into the edit: one after the other from where they start, each for its length
/// (a video's whole part, a photo's three seconds), never past the room there is (the end of the video, or the next support
/// of a split screen). What doesn't fit is said before it goes in: the last that fits is shortened and the rest left out, and
/// the edit never grows to make room. Pure, so the sheet and the tests agree.
nonisolated struct MediaRun: Equatable, Sendable {
    /// Where each one goes (edited seconds), by its place in the pick; shortened when the room ran out within it.
    struct Placed: Equatable, Sendable {
        var index: Int
        var span: TimeSpan
        var isShortened: Bool
    }

    var placed: [Placed]
    /// How many at the end of the pick didn't fit at all.
    var leftOut: Int
    /// How long they all wanted, and how much room there is.
    var wanted: TimeInterval
    var room: TimeInterval

    var fitsWhole: Bool { leftOut == 0 && !placed.contains(where: \.isShortened) }
    var end: TimeInterval? { placed.last?.span.end }

    /// `lengths` laid one after the other from `start`, in `room` seconds.
    init(lengths: [TimeInterval], from start: TimeInterval, room: TimeInterval) {
        var placed: [Placed] = []
        var cursor = start
        let limit = start + max(0, room)
        for (index, length) in lengths.enumerated() {
            let left = limit - cursor
            guard left >= MediaOverlay.minimumDuration else { break }
            let shown = min(max(length, MediaOverlay.minimumDuration), left)
            placed.append(Placed(index: index, span: TimeSpan(start: cursor, end: cursor + shown), isShortened: shown < length - 0.000_1))
            cursor += shown
        }
        self.placed = placed
        leftOut = lengths.count - placed.count
        wanted = lengths.reduce(0, +)
        self.room = max(0, room)
    }
}
