//
//  MessageTimeline.swift
//  Cue Studio
//

import Foundation

/// The second of 1.4's board for a chapter that has been on screen a while (09 §16). The board plays the writing at fixed times (the card opens,
/// the words arrive from 1.9 s, the check at 5.5 s, the capsule at 6.2 s…) because its message is already there; here the message comes
/// from the model whenever it comes. So the board's clock follows the real one up to 1.9 s, waits there until the message is in, and goes on
/// from there at the same pace.
enum MessageTimeline {
    /// The second of the board at which the words begin to arrive.
    static let writingStarts = 1.9
    /// The board is complete: the capsule has run and the button shines (the board loops at 11 s).
    static let end = 10.0

    /// - Parameters:
    ///   - seconds: how long the chapter has been on screen.
    ///   - arrivedAt: the second (on screen) the message came in, or nil while it hasn't.
    static func boardSecond(seconds: Double, arrivedAt: Double?) -> Double {
        guard seconds > writingStarts else { return seconds }
        guard let arrivedAt else { return writingStarts }
        let start = max(writingStarts, arrivedAt)
        guard seconds > start else { return writingStarts }
        return min(end, writingStarts + (seconds - start))
    }

    /// How long the model has kept the creator waiting (the first message is "slow" past 6 s, the way out is offered past 15 s).
    static let slowAfter = 6.0
    static let readyMadeAfter = 15.0
}
