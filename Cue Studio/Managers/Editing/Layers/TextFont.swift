//
//  TextFont.swift
//  Cue Studio
//

import CoreText
import UIKit

/// The UIFont for a text on the video, the same in the preview, the export and the editor's
/// sample cards. The bundled faces are variable (DM Sans: weight and optical size; Space Grotesk:
/// weight, 300 to 700) except DM Serif Display. Text in a script the face doesn't cover uses the
/// system font at the same weight, so every language keeps its letters.
nonisolated enum TextFont {
    private static let wght: NSNumber = 0x7767_6874
    private static let opsz: NSNumber = 0x6F70_737A

    static func font(_ face: TextOverlayFont, weight: TextOverlayWeight, size: CGFloat, text: String) -> UIFont {
        let system = UIFont.systemFont(ofSize: size, weight: uiWeight(weight))
        switch face {
        case .classic, .sfPro: return system
        case .rounded: return designed(system, .rounded)
        case .serif: return designed(system, .serif)
        case .mono: return designed(system, .monospaced)
        case .dmSans:
            return bundled("DMSans-9ptRegular", size: size, axes: [wght: weight.value, opsz: Double(min(max(size, 9), 40))], text: text, fallback: system)
        case .spaceGrotesk:
            return bundled("SpaceGrotesk-Light", size: size, axes: [wght: min(max(weight.value, 300), 700)], text: text, fallback: system)
        case .dmSerif:
            return bundled("DMSerifDisplay-Regular", size: size, axes: [:], text: text, fallback: designed(system, .serif))
        case .unbounded:
            return bundled("Unbounded-Regular", size: size, axes: [wght: min(max(weight.value, 200), 900)], text: text, fallback: system)
        case .instrumentSerif:
            return bundled("InstrumentSerif-Italic", size: size, axes: [:], text: text, fallback: designed(system, .serif))
        case .spaceMono:
            return bundled("SpaceMono-Bold", size: size, axes: [:], text: text, fallback: designed(system, .monospaced))
        case .anton:
            return bundled("Anton-Regular", size: size, axes: [:], text: text, fallback: system)
        case .syne:
            return bundled("Syne-Regular", size: size, axes: [wght: min(max(weight.value, 400), 800)], text: text, fallback: system)
        case .caveat:
            return bundled("Caveat-Regular", size: size, axes: [wght: min(max(weight.value, 400), 700)], text: text, fallback: system)
        }
    }

    static func uiWeight(_ weight: TextOverlayWeight) -> UIFont.Weight {
        switch weight {
        case .regular: .regular
        case .medium: .medium
        case .semibold: .semibold
        case .bold: .bold
        case .heavy: .heavy
        }
    }

    private static func designed(_ font: UIFont, _ design: UIFontDescriptor.SystemDesign) -> UIFont {
        guard let descriptor = font.fontDescriptor.withDesign(design) else { return font }
        return UIFont(descriptor: descriptor, size: font.pointSize)
    }

    private static func bundled(_ name: String, size: CGFloat, axes: [NSNumber: Double], text: String, fallback: UIFont) -> UIFont {
        guard let base = UIFont(name: name, size: size) else { return fallback }
        var font = base
        if !axes.isEmpty {
            let variation = axes.mapValues { NSNumber(value: $0) }
            let descriptor = base.fontDescriptor.addingAttributes([
                UIFontDescriptor.AttributeName(rawValue: kCTFontVariationAttribute as String): variation,
            ])
            font = UIFont(descriptor: descriptor, size: size)
        }
        return covers(font, text) ? font : fallback
    }

    /// Whether the face has every letter of `text` (spaces aside).
    private static func covers(_ font: UIFont, _ text: String) -> Bool {
        let characters = Array(text.unicodeScalars.filter { !CharacterSet.whitespacesAndNewlines.contains($0) }.map(String.init).joined().utf16)
        guard !characters.isEmpty else { return true }
        var glyphs = [CGGlyph](repeating: 0, count: characters.count)
        return CTFontGetGlyphsForCharacters(font as CTFont, characters, &glyphs, characters.count)
    }
}
