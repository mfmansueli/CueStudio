//
//  RecordedClip.swift
//  Cue Studio
//

import Foundation

/// A finished recording still in the temporary folder.
nonisolated struct RecordedClip: Hashable, Sendable {
    var url: URL
    var duration: TimeInterval
}
