//
//  CaptionOrigin.swift
//  Cue Studio
//

import Foundation

/// Where a caption came from.
nonisolated enum CaptionOrigin: String, Codable, Sendable {
    /// Heard in the take by on-device speech recognition.
    case speech
    /// Written by the creator.
    case manual
    /// Made before captions kept their words (from the voice, or spread over the take).
    case legacy
}
