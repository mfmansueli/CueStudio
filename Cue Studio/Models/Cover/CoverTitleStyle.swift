//
//  CoverTitleStyle.swift
//  Cue Studio
//

import Foundation

/// How a cover's title is set: where its block sits and how wide it may be, how big the words are at most (they get smaller
/// to fit the block, never cut: `CoverTextLayout`), their alignment, type and colors, what keeps them readable, which words
/// are highlighted and how, capitals, and the small line over them (a kicker: "EP 03", "HOW TO").
nonisolated struct CoverTitleStyle: Codable, Hashable, Sendable {
    /// Widest and narrowest the block can be, as a share of the cover's width.
    static let widthRange: ClosedRange<Double> = 0.4...0.94
    /// Largest and smallest the words can be asked to be, as a share of the cover's width.
    static let sizeRange: ClosedRange<Double> = 0.05...0.2

    /// The block's center, as fractions of the cover from the top left.
    var center = OverlayPoint(x: 0.5, y: 0.3)
    var width = 0.86
    /// The size of the words, as a share of the cover's width, before fitting.
    var size = 0.12
    var alignment: LineAlignment = .center
    var font: CoverFont = .anton
    var textColor: OverlayColor = .white
    /// The highlighted words' color, or their box's.
    var accent: OverlayColor = .yellow
    var highlightStyle: CoverHighlightStyle = .box
    /// Which words are highlighted, by position among the title's words (`CoverWords`).
    var highlights: Set<Int> = []
    var background: CoverTextBackground = .shadow
    /// The box behind the block, with `background == .box`.
    var boxColor: OverlayColor = .offBlack
    var uppercase = true
    /// The small line over the title; empty for none.
    var kicker = ""
    /// The title's first number drawn big over the rest (a listicle).
    var showsNumber = false

    /// Kept in its ranges.
    var clamped: CoverTitleStyle {
        var style = self
        style.center = center.clamped
        style.width = min(max(width, Self.widthRange.lowerBound), Self.widthRange.upperBound)
        style.size = min(max(size, Self.sizeRange.lowerBound), Self.sizeRange.upperBound)
        return style
    }
}
