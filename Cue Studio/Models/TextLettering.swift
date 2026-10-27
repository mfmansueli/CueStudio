//
//  TextLettering.swift
//  Cue Studio
//

import Foundation

/// How a text's letters are drawn (`TextOverlayRenderer`). `centered`, the first way: the outline on the letters' edges, over
/// their fill, and the shadow cast by each. `outside`: the outline wholly outside the letters, behind their fill, with round
/// joins, and one soft shadow under letters and outline together (a filled box casts its own). A text or look saved before
/// `outside` existed reads `centered`, so a video already made looks as it did; everything made now is `outside`.
nonisolated enum TextLettering: String, Codable, Sendable {
    case centered
    case outside

    /// A saved text's or look's: `centered` when it was saved without one; one a newer version wrote reads as today's.
    static func read(_ raw: String?) -> TextLettering {
        guard let raw else { return .centered }
        return TextLettering(rawValue: raw) ?? .outside
    }
}
