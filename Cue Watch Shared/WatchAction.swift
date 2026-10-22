//
//  WatchAction.swift
//  Cue Studio
//

import Foundation

/// What the Apple Watch asks the iPhone's recorder to do. The watch only asks: its screen changes when the iPhone answers with
/// its state (`WatchPhoneState`), never on the tap alone.
nonisolated enum WatchAction: Codable, Hashable, Sendable {
    /// Just the iPhone's state (opening the app, raising the wrist, Try again).
    case refresh
    /// Record: the countdown when the iPhone has one, then the take. From a saved take, another take.
    case record
    /// Stops the countdown before anything records.
    case cancelCountdown
    /// Ends the take; the iPhone saves it.
    case stop
    /// Plays the script without recording.
    case rehearse
    case endRehearsal
    /// Reads or pauses the script (the camera goes on while recording).
    case togglePlay
    /// Back three lines, to say a sentence again.
    case backward
    case faster
    case slower
    /// The Digital Crown's speed, as times the natural reading pace (`speedMultiple`).
    case setSpeed(multiple: Double)
    /// "Done" on a saved take: the watch leaves it; the iPhone's review stays open.
    case done
}
