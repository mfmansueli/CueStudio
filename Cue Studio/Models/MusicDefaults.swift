//
//  MusicDefaults.swift
//  Cue Studio
//

import Foundation

/// How music added to this video starts: its volume and how far it goes down under the voice. A kit's Editing puts them on a
/// video (`BrandKitEditing`); music already there keeps its own. Nil on an edit: the editor's (40%, `MusicDuck.standard`).
nonisolated struct MusicDefaults: Codable, Hashable, Sendable {
    /// What music added starts at without one: 40%.
    static let standardVolume: Double = 0.4

    /// 0 to 1.
    var volume: Double
    var duck: MusicDuck
}
