//
//  SoundExtraction.swift
//  Cue Studio
//

import Foundation

/// What Extract audio takes out of a recording: a stretch of its sound, played at the clip's speed (or along its curve), as
/// the edit treats it.
nonisolated struct SoundExtraction: Sendable {
    /// The recording's file (the take's video, another recording's, a video over the take).
    var videoURL: URL
    /// Seconds of the recording.
    var span: TimeSpan
    /// The clip's speed: 2 makes the sound twice as fast (half as long), like the clip plays.
    var speed: Double = 1
    /// A faster or slower clip keeps the voice's tone (`EditSegment.keepsPitch`).
    var keepsPitch = true
    /// The clip's speed curve: the sound comes out along it, as the clip plays (`speed` is then not used).
    var curve: SpeedCurve?
    /// For a clip of the timeline, the edit and the recording (nil: the take), so the sound comes out as Studio Voice treats
    /// it (`RecordingSounds`); nil for a video over the take, which is never treated.
    var treatment: Treatment?

    nonisolated struct Treatment: Sendable {
        var edit: TakeEdit
        /// The take's video (the other recordings are read from the edit's media).
        var takeURL: URL
        var recording: UUID?
    }
}
