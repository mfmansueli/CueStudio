//
//  EditPlayback.swift
//  Cue Studio
//

import AVFoundation
import Foundation

/// Quick edit's transport and clock. The screen reads the playhead from here, never from a copy
/// of its own; tests use a fake.
protocol EditPlayback: AnyObject {
    /// The player the preview draws.
    var avPlayer: AVPlayer { get }
    /// Edited seconds: where the playhead is.
    var currentTime: TimeInterval { get }
    var isPlaying: Bool { get }
    var state: EditPlaybackState { get }
    /// A rebuild is taking long enough to say so.
    var isProcessing: Bool { get }
    /// A part under review (edited seconds): "Remove part"'s red range. Playing from before its
    /// end stops exactly at its end instead of running on; from its end, it plays the part again.
    var reviewedPart: ClosedRange<TimeInterval>? { get set }
    /// Silent while a voice-over is recorded, so the take's sound doesn't leak into it.
    var isMuted: Bool { get set }
    /// The scene is recorded or mirrored (`SceneCaptured`): turning it on pauses, and while it is on nothing plays (a tap, an
    /// audio session coming ready, a seek or rebuild landing, a preview of a change). Turning it off leaves the playhead where
    /// it was, paused: playback never starts on its own. Seeking still moves the playhead (the timeline edits around it).
    var isPlaybackBlocked: Bool { get set }

    /// Plays `edit` from now on, keeping the playhead on the same moment of the recording (or
    /// where the edit picks up, when that moment was cut).
    func show(_ edit: TakeEdit)
    func play()
    func pause()
    func togglePlayback()
    /// Jumps exactly to `time` (edited seconds).
    func seek(to time: TimeInterval)
    /// Follows a finger: pauses, and keeps up with the latest time.
    func scrub(to time: TimeInterval)
    func endScrub()
    /// Stops for good, when Quick edit closes.
    func stop()
    /// `hold` gets the picture on screen right before the player swaps to an item with other pieces
    /// or tracks, to show until the new item has a picture of its own. Kept while `owner` lives.
    func addFrameHolder(_ owner: AnyObject, hold: @escaping @MainActor (CGImage) -> Void)
}
