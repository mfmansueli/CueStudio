//
//  TextFont.swift
//  Cue Studio
//

import CoreText
import UIKit

/// The UIFont for words on the video, the same in the preview, the export and the editor's
/// sample cards. Most bundled faces are variable (DM Sans and TikTok Sans: weight and optical size;
/// the others: weight, within their own range); Poppins comes as one file per weight. Text in a
/// script the face doesn't cover uses the system font at the same weight, so every language keeps
/// its letters.
nonisolated enum TextFont {
    private static let wght: NSNumber = 0x7767_6874
    private static let opsz: NSNumber = 0x6F70_737A

    /// A bundled family: its registered name, the range of its weight axis (nil: one cut), of its optical-size axis, and
    /// the system design that stands in for letters it lacks.
    private struct Bundled {
        let name: String
        var weights: ClosedRange<Double>?
        var opticalSizes: ClosedRange<Double>?
        var design: UIFontDescriptor.SystemDesign = .default
    }

    private static let bundledFaces: [TextOverlayFont: Bundled] = [
        .dmSans: Bundled(name: "DMSans-9ptRegular", weights: 100...1000, opticalSizes: 9...40),
        .spaceGrotesk: Bundled(name: "SpaceGrotesk-Light", weights: 300...700),
        .dmSerif: Bundled(name: "DMSerifDisplay-Regular", design: .serif),
        .unbounded: Bundled(name: "Unbounded-Regular", weights: 200...900),
        .instrumentSerif: Bundled(name: "InstrumentSerif-Italic", design: .serif),
        .spaceMono: Bundled(name: "SpaceMono-Bold", design: .monospaced),
        .anton: Bundled(name: "Anton-Regular"),
        .syne: Bundled(name: "Syne-Regular", weights: 400...800),
        .caveat: Bundled(name: "Caveat-Regular", weights: 400...700),
        .montserrat: Bundled(name: "Montserrat-Regular", weights: 100...900),
        .tiktokSans: Bundled(name: "TikTokSans-Regular", weights: 300...900, opticalSizes: 12...36),
        .rubik: Bundled(name: "Rubik-Light", weights: 300...900),
        .bangers: Bundled(name: "Bangers-Regular"),
    ]

    static func font(_ face: TextOverlayFont, weight: TextOverlayWeight, size: CGFloat, text: String) -> UIFont {
        let system = UIFont.systemFont(ofSize: size, weight: uiWeight(weight))
        switch face {
        case .classic, .sfPro: return system
        case .rounded: return designed(system, .rounded)
        case .serif: return designed(system, .serif)
        case .mono: return designed(system, .monospaced)
        case .poppins:
            // One file per weight: Regular, Medium, Bold (Semibold too) and ExtraBold for Heavy.
            let name = switch weight {
            case .regular: "Poppins-Regular"
            case .medium: "Poppins-Medium"
            case .semibold, .bold: "Poppins-Bold"
            case .heavy: "Poppins-ExtraBold"
            }
            return bundled(name, size: size, axes: [:], text: text, fallback: system)
        default:
            guard let spec = bundledFaces[face] else { return system }
            var axes: [NSNumber: Double] = [:]
            if let range = spec.weights { axes[wght] = min(max(weight.value, range.lowerBound), range.upperBound) }
            if let range = spec.opticalSizes { axes[opsz] = min(max(Double(size), range.lowerBound), range.upperBound) }
            let fallback = spec.design == .default ? system : designed(system, spec.design)
            return bundled(spec.name, size: size, axes: axes, text: text, fallback: fallback)
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
