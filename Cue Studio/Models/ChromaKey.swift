//
//  ChromaKey.swift
//  Cue Studio
//

import Foundation

/// A green or blue screen taken out: the key color, how far from it a color still counts as the
/// screen (tolerance), how soft the edge is, and how much of the screen's tint is taken off the
/// creator (spill). Colors are sRGB, 0 to 1.
nonisolated struct ChromaKey: Codable, Hashable, Sendable {
    static let green = ChromaKey(red: 0.0, green: 0.69, blue: 0.25)
    static let blue = ChromaKey(red: 0.0, green: 0.28, blue: 0.73)

    var red: Double
    var green: Double
    var blue: Double
    /// 0 to 1: how far from the key a color still disappears.
    var tolerance: Double = 0.3
    /// 0 to 1: how wide the edge between gone and kept is.
    var softness: Double = 0.15
    /// 0 to 1: how much of the key's tint is taken off what stays.
    var spill: Double = 0.5

    init(red: Double, green: Double, blue: Double) {
        self.red = red
        self.green = green
        self.blue = blue
    }

    /// The same settings with another key color.
    func keying(red: Double, green: Double, blue: Double) -> ChromaKey {
        var copy = self
        copy.red = red
        copy.green = green
        copy.blue = blue
        return copy
    }
}
