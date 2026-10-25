//
//  CustomFontFace.swift
//  Cue Studio
//

import Foundation

/// One face of a family the creator imported: its file in `CustomFontFiles`, the PostScript name it is registered under, its
/// style ("Bold Italic"), its CSS-style weight (100 to 900, from the font's own OS/2 table) and, for a variable font, the
/// range of its weight axis.
nonisolated struct CustomFontFace: Codable, Hashable, Sendable {
    var fileName: String
    var postScriptName: String
    var styleName: String
    var weight: Double
    var isItalic: Bool
    var weightRange: ClosedRange<Double>?

    /// The editor weights this face draws: every one its axis reaches, or the one nearest its own weight.
    var editorWeights: [TextOverlayWeight] {
        if let weightRange {
            let reached = TextOverlayWeight.editorWeights.filter { weightRange.contains($0.value) }
            return reached.isEmpty ? [TextOverlayWeight.nearest(to: weight, in: TextOverlayWeight.editorWeights)] : reached
        }
        return [TextOverlayWeight.nearest(to: weight, in: TextOverlayWeight.editorWeights)]
    }
}
