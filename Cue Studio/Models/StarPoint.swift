//
//  StarPoint.swift
//  Cue Studio
//

import Foundation

/// One of "your stars" in the sky above Scripts: a spot normalised to 0...1 on both axes.
nonisolated struct StarPoint: Codable, Hashable, Sendable {
    var x: Double
    var y: Double
}
