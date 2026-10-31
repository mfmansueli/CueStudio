//
//  CaptionStyleSpec+Script.swift
//  Cue Studio
//

import Foundation

/// A caption recipe's face as the other scripts see it: its character, and the weight their faces are drawn at.
nonisolated extension CaptionStyleSpec {
    var typeCharacter: TypeCharacter {
        face?.character ?? TextOverlayFont.character(ofFontNamed: fontName)
    }

    /// The weight another script's face draws at: the family's, as heavy as it looks (Anton and Bangers are heavy in their one
    /// cut), or the recipe's own reserve weight for the presets that name a file.
    var scriptWeight: TextOverlayWeight {
        if let face { return face.scriptWeight(TextOverlayWeight.nearest(to: fontWeight, in: face.weights)) }
        if typeCharacter == .condensed { return .heavy }
        return TextOverlayWeight.nearest(to: fallbackWeight, in: TextOverlayWeight.allCases)
    }
}
