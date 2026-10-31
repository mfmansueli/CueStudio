//
//  CaptionFont.swift
//  Cue Studio
//

import UIKit

/// A caption recipe's font for `text`: the family picked over it (`CaptionStyleSpec.face`) or the preset's own file, drawing
/// every script through `ScriptFontCascade` (the face with the style's character in Japanese, Arabic, Thai…, at the style's
/// weight), so each style keeps its personality in every language, the same in the preview and the export.
nonisolated enum CaptionFont {
    static func font(spec: CaptionStyleSpec, size: CGFloat, text: String) -> UIFont {
        if let face = spec.face {
            return TextFont.font(face, weight: TextOverlayWeight.nearest(to: spec.fontWeight, in: face.weights), size: size, text: text)
        }
        return TextFont.named(
            spec.fontName, variation: spec.fontWeight, size: size, text: text, character: spec.typeCharacter, scriptWeight: spec.scriptWeight,
            systemWeight: systemWeight(spec.fallbackWeight)
        )
    }

    /// The system font's weight a line the preset's file draws none of is set in (as Cue always set it).
    private static func systemWeight(_ weight: Double) -> UIFont.Weight {
        weight >= 800 ? .heavy : weight >= 700 ? .bold : .semibold
    }
}
