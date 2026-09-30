//
//  ImportedAudio.swift
//  Cue Studio
//

import Foundation

/// A sound file from Files copied into `EditMediaFiles`, with what the edit needs to know about it.
nonisolated struct ImportedAudio: Hashable, Sendable {
    let fileName: String
    /// The file's name, without its extension.
    let title: String
    let duration: TimeInterval
}
