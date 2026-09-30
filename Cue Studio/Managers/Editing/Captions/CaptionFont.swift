//
//  CaptionFont.swift
//  Cue Studio
//

import CoreText
import UIKit

/// UIKit's system cascades shape Arabic, Devanagari, CJK and Thai locally. A whole unsupported
/// script uses the system weight to avoid mixing a Latin display cut with missing glyph boxes.
nonisolated enum CaptionFont {
    static func font(theme: CaptionTheme, size: CGFloat, text: String) -> UIFont {
        let weight: UIFont.Weight = theme == .clean ? .semibold : (theme == .pop ? .heavy : .bold)
        let fallback = UIFont.systemFont(ofSize: size, weight: weight)
        guard let bundled = UIFont(name: theme.fontName, size: size) else { return fallback }
        let variation: [NSNumber: NSNumber] = [0x77676874: NSNumber(value: theme.fontWeight)]
        let descriptor = bundled.fontDescriptor.addingAttributes([
            UIFontDescriptor.AttributeName(rawValue: kCTFontVariationAttribute as String): variation,
        ])
        let font = UIFont(descriptor: descriptor, size: size)
        let characters = Array(text.unicodeScalars.filter { !CharacterSet.whitespacesAndNewlines.contains($0) }.map(String.init).joined().utf16)
        var glyphs = [CGGlyph](repeating: 0, count: characters.count)
        let covered = CTFontGetGlyphsForCharacters(font as CTFont, characters, &glyphs, characters.count)
        return covered ? font : fallback
    }
}
