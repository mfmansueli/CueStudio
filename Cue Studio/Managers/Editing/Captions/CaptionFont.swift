//
//  CaptionFont.swift
//  Cue Studio
//

import CoreText
import UIKit

/// UIKit's system cascades shape Arabic, Devanagari, CJK and Thai locally. A whole unsupported
/// script uses the system weight to avoid mixing a Latin display cut with missing glyph boxes.
nonisolated enum CaptionFont {
    /// The font of the first reading of a preset.
    static func font(theme: CaptionTheme, size: CGFloat, text: String) -> UIFont {
        font(spec: CaptionStyleSpec.spec(for: theme, version: 1), size: size, text: text)
    }

    static func font(spec: CaptionStyleSpec, size: CGFloat, text: String) -> UIFont {
        let fallback = UIFont.systemFont(ofSize: size, weight: systemWeight(spec.fallbackWeight))
        guard let bundled = UIFont(name: spec.fontName, size: size) else { return fallback }
        let variation: [NSNumber: NSNumber] = [0x77676874: NSNumber(value: spec.fontWeight)]
        let descriptor = bundled.fontDescriptor.addingAttributes([
            UIFontDescriptor.AttributeName(rawValue: kCTFontVariationAttribute as String): variation,
        ])
        let font = UIFont(descriptor: descriptor, size: size)
        let characters = Array(text.unicodeScalars.filter { !CharacterSet.whitespacesAndNewlines.contains($0) }.map(String.init).joined().utf16)
        var glyphs = [CGGlyph](repeating: 0, count: characters.count)
        let covered = CTFontGetGlyphsForCharacters(font as CTFont, characters, &glyphs, characters.count)
        return covered ? font : fallback
    }

    private static func systemWeight(_ weight: Double) -> UIFont.Weight {
        weight >= 800 ? .heavy : weight >= 700 ? .bold : .semibold
    }

    /// Whether letters can be spaced out: not in scripts whose letters join (Arabic) or stack
    /// (Devanagari, Thai), where added space breaks the writing.
    static func allowsTracking(in text: String) -> Bool {
        !text.unicodeScalars.contains { scalar in
            switch scalar.value {
            case 0x0600...0x06FF, 0x0750...0x077F, 0x08A0...0x08FF, 0xFB50...0xFDFF, 0xFE70...0xFEFF, 0x0900...0x097F, 0x0E00...0x0E7F: true
            default: false
            }
        }
    }
}
