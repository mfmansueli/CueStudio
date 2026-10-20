//
//  TextChipMetrics.swift
//  Cue Studio
//

import SwiftUI
import UIKit

/// The geometry of a `TextChip` in text of `textSize` points, shared by the editor and `ArrivingText` so a chip looks the same in both:
/// semibold words at 72% of the text, their capitals centred on the line's capitals, in a chip a little taller than its words with a
/// radius of at most 8 pt.
nonisolated struct TextChipMetrics: Equatable, Sendable {
    let textSize: CGFloat

    /// The chip's words: 13.7 pt in 19 pt text.
    var fontSize: CGFloat { textSize * 0.72 }
    var font: UIFont { .systemFont(ofSize: fontSize, weight: .semibold) }
    private var bodyFont: UIFont { .systemFont(ofSize: textSize) }

    /// How far the chip's words are raised so their capitals sit centred on the capitals of the text around them.
    var baselineOffset: CGFloat { ((bodyFont.capHeight - font.capHeight) / 2).rounded(toPlaces: 1) }
    var height: CGFloat { (font.lineHeight + fontSize * 0.36).rounded() }
    var cornerRadius: CGFloat { min(8, height / 2) }
    static let rimWidth: CGFloat = 0.5

    /// The space between the chip's edges and its words (or its symbol).
    var inset: CGFloat { (fontSize * 0.5).rounded() }
    /// The symbol's point size, and the narrowest box it is centred in before the words (a wide one, the tortoise, gets its own width).
    var symbolPointSize: CGFloat { (fontSize * 0.82).rounded() }
    private var symbolBox: CGFloat { fontSize.rounded() }
    private var symbolGap: CGFloat { (fontSize * 0.3).rounded() }
    var symbolConfiguration: UIImage.SymbolConfiguration { UIImage.SymbolConfiguration(pointSize: symbolPointSize, weight: .semibold) }

    /// The width a symbol takes in the chip.
    func symbolWidth(_ symbol: String) -> CGFloat {
        let width = UIImage(systemName: symbol, withConfiguration: symbolConfiguration)?.size.width ?? 0
        return max(symbolBox, width.rounded(.up))
    }

    /// The space before the chip's words: the inset, and the symbol with its gap when it has one.
    func leadingSpace(symbol: String?) -> CGFloat {
        inset + (symbol.map { symbolWidth($0) + symbolGap } ?? 0)
    }

    /// The kern a hidden first character of `font` needs so the words start `leadingSpace` from the chip's edge (it is drawn clear,
    /// its own width counts).
    func leadingKern(after character: String, symbol: String?) -> CGFloat {
        leadingSpace(symbol: symbol) - advance(of: character)
    }

    /// The kern a hidden last character needs so the chip ends `inset` after the words.
    func trailingKern(after character: String) -> CGFloat {
        inset - advance(of: character)
    }

    private func advance(of character: String) -> CGFloat {
        (character as NSString).size(withAttributes: [.font: font]).width
    }

    /// The chip between two x positions on a line whose baseline is at `baseline` (y grows downwards).
    func chipRect(from minX: CGFloat, to maxX: CGFloat, baseline: CGFloat) -> CGRect {
        let centre = baseline - bodyFont.capHeight / 2
        return CGRect(x: minX, y: centre - height / 2, width: max(0, maxX - minX), height: height)
    }

    /// Where `symbol` is centred inside a chip.
    func symbolCentre(_ symbol: String, in chip: CGRect) -> CGPoint {
        CGPoint(x: chip.minX + inset + symbolWidth(symbol) / 2, y: chip.midY)
    }
}

private extension CGFloat {
    nonisolated func rounded(toPlaces places: Int) -> CGFloat {
        let scale = pow(10, CGFloat(places))
        return (self * scale).rounded() / scale
    }
}
