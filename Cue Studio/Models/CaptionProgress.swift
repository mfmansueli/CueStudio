//
//  CaptionProgress.swift
//  Cue Studio
//

import Foundation

/// Where listening to a take for captions is.
nonisolated enum CaptionProgress: Equatable, Sendable {
    /// Reading the sound and finding a speech model for the language.
    case preparing
    /// Downloading the language's speech model (the system's own download), 0 to 1 when known.
    case downloading(Double?)
    /// Listening to the take, 0 to 1 of its length.
    case transcribing(Double)
}
