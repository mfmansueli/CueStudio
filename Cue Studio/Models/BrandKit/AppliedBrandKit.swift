//
//  AppliedBrandKit.swift
//  Cue Studio
//

import Foundation

/// The brand kit last put on a video, as it was then: its name (the ✦ Smart › Brand card is marked) and its colors, first in
/// the video's color pickers. Changing or deleting the kit later doesn't change this.
nonisolated struct AppliedBrandKit: Codable, Hashable, Sendable {
    var id: UUID
    var name: String
    var colors: [OverlayColor]
}
