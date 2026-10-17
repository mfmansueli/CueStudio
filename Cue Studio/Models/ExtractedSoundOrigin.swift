//
//  ExtractedSoundOrigin.swift
//  Cue Studio
//

import Foundation

/// Where a sound on the music track was taken from with Extract audio: a clip of the timeline (the take or another
/// recording) or a video laid over it. Like a sound effect, it follows the moment it came from when something before it is
/// cut, and it never takes music's room.
nonisolated enum ExtractedSoundOrigin: String, Codable, Sendable {
    case clip, media
}
