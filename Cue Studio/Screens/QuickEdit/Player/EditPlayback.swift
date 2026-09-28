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
}
