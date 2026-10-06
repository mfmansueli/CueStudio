//
//  PracticeStage.swift
//  Cue Studio
//

import Foundation

/// Where the first flight's practice run is (1.6, 09 §17). Nothing runs by itself: the text waits behind a dim layer for the tap on the play
/// button, Cue counts the creator in (GET READY, 3, 2, 1, READ!), the text then scrolls (following the voice, or at the set speed), and when it
/// has all been read a card says so.
nonisolated enum PracticeStage: Equatable, Sendable {
    /// Waiting for the tap.
    case idle
    /// Counting in since this moment: the second of the board's count-in is `PracticeStage.tapSecond` plus the time since.
    case counting(since: Date)
    /// The text is moving.
    case reading
    /// The text has been read to its end.
    case done

    /// The text is still dimmed: waiting for the tap, or counting in.
    var isWaiting: Bool {
        switch self {
        case .idle, .counting: true
        case .reading, .done: false
        }
    }

    /// The board's demo taps the play button at 2.2 s of its 20.4 s timeline; the count-in and the reveal are read from there.
    static let tapSecond = 2.2
    /// The count-in lasts until the text starts to move: READ! lifts the dim at 5.95 s (3.75 s after the tap).
    static let countInDuration = 3.75
}
