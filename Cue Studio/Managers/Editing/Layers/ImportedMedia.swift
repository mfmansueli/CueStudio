//
//  ImportedMedia.swift
//  Cue Studio
//

import Foundation

/// A photo or video copied from the library into `EditMediaFiles`, with what the edit needs to
/// know about it.
nonisolated struct ImportedMedia: Hashable, Sendable {
    let kind: MediaKind
    let fileName: String
    /// Width over height, upright.
    let aspect: Double
    /// Length of a video; nil for a photo.
    let duration: TimeInterval?
}
