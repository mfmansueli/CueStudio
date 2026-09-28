//
//  EditSourceError.swift
//  Cue Studio
//

import Foundation

/// Why a take's recording can't be edited.
nonisolated enum EditSourceError: Error, Equatable {
    /// The file is no longer in the Takes folder.
    case missing
    /// The file has no picture (or isn't a video).
    case noVideo
    /// The file reads as empty.
    case noDuration
}
