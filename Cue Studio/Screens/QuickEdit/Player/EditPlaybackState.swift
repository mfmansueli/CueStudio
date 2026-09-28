//
//  EditPlaybackState.swift
//  Cue Studio
//

import Foundation

/// Whether the Quick edit preview has something to play.
nonisolated enum EditPlaybackState: Equatable, Sendable {
    /// The first item is being built.
    case loading
    case ready
    /// The edit couldn't be built into something playable.
    case failed
}
