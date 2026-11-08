//
//  RecordingPauseHearing.swift
//  Cue Studio
//

import Foundation

/// How Clean Up heard one recording's pauses, kept with the edit so Pauses says it again when the editor reopens (the recording
/// isn't listened to twice). Only recordings not heard clearly are kept.
nonisolated struct RecordingPauseHearing: Codable, Hashable, Sendable {
    /// The recording: nil for the take, else another recording of the montage (`ClipSource.id`).
    var sourceID: UUID?
    var hearing: PauseHearing
}
