//
//  TextFont.swift
//  Cue Studio
//

import CoreText
import UIKit

/// The UIFont for words on the video, the same in the preview, the export and the editor's
/// sample cards. Most bundled faces are variable (DM Sans and TikTok Sans: weight and optical size;
/// the others: weight, within their own range); Poppins comes as one file per weight. Words in another
/// script draw in that script's face with the same character and weight (`ScriptFontCascade`), so a style
/// keeps its personality in Japanese, Arabic or Thai; Latin letters the face lacks (Vietnamese in some)
/// move the whole text to a Latin face like it that has them.
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
        let base = latinFont(face, weight: weight, size: size, text: text)
        if face.pack == nil, face.customFamily == nil, ScriptFontCascade.setsOnSystem(base.font, text) {
            return ScriptFontCascade.font(
                ScriptFontCascade.system(size: size, weight: weight, design: base.design), character: face.character,
                weight: face.scriptWeight(weight), text: text, design: base.design, systemFaces: false
            )
        }
        return ScriptFontCascade.font(base.font, character: face.character, weight: face.scriptWeight(weight), text: text, design: base.design)
    }

    /// A caption preset's own bundled file (`CaptionStyleSpec.fontName`) at a point on its weight axis, drawing every script
    /// like any face: `character` and `scriptWeight` pick the other scripts' faces; a Latin face of the same character stands
    /// in when the file is missing or lacks Latin letters of `text`, and a line the file draws none of is set on the system
    /// font at `systemWeight`.
    static func named(
        _ name: String, variation: Double, size: CGFloat, text: String, character: TypeCharacter, scriptWeight: TextOverlayWeight,
        systemWeight: UIFont.Weight
    ) -> UIFont {
        var font = UIFont(name: name, size: size)
        if let named = font {
            let descriptor = named.fontDescriptor.addingAttributes([
                UIFontDescriptor.AttributeName(rawValue: kCTFontVariationAttribute as String): [wght: NSNumber(value: variation)],
            ])
            font = UIFont(descriptor: descriptor, size: size)
        }
        guard let font, ScriptFontCascade.coversLatin(font, text) else {
            return Self.font(ScriptTypeMap.latinStandIn(for: character), weight: scriptWeight, size: size, text: text)
        }
        guard !ScriptFontCascade.setsOnSystem(font, text) else {
            return ScriptFontCascade.font(
                UIFont.systemFont(ofSize: size, weight: systemWeight), character: character, weight: scriptWeight, text: text, systemFaces: false
            )
        }
        return ScriptFontCascade.font(font, character: character, weight: scriptWeight, text: text)
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

    // MARK: - Private

    /// The face itself, before the other scripts: the bundled file at its weight, an imported family, a library family, or
    /// a system design; the design the system font keeps after it.
    private static func latinFont(
        _ face: TextOverlayFont, weight: TextOverlayWeight, size: CGFloat, text: String
    ) -> (font: UIFont, design: UIFontDescriptor.SystemDesign) {
        let system = UIFont.systemFont(ofSize: size, weight: uiWeight(weight))
        if let family = face.customFamily {
            // An imported family not on this iPhone draws in SF Pro (the panel says so). Letters it lacks come from the
            // cascade one by one: an imported family covers what its maker drew, and the rest of the line keeps it.
            guard let match = CustomFontRegistry.shared.face(of: family, weight: weight) else { return (system, .default) }
            return (imported(match, weight: weight, size: size) ?? system, .default)
        }
        if let pack = face.pack {
            return (ScriptFontCascade.font(pack: pack, weight: weight, size: size, text: ""), .default)
        }
        switch face {
        case .classic, .sfPro: return (system, .default)
        case .rounded: return (designed(system, .rounded), .rounded)
        case .serif: return (designed(system, .serif), .serif)
        case .mono: return (designed(system, .monospaced), .monospaced)
        case .poppins:
            // One file per weight: Regular, Medium, Bold (Semibold too) and ExtraBold for Heavy.
            let name = switch weight {
            case .regular: "Poppins-Regular"
            case .medium: "Poppins-Medium"
            case .semibold, .bold: "Poppins-Bold"
            case .heavy: "Poppins-ExtraBold"
            }
            return (bundled(name, face: face, weight: weight, size: size, axes: [:], text: text), .default)
        default:
            guard let spec = bundledFaces[face] else { return (system, .default) }
            var axes: [NSNumber: Double] = [:]
            if let range = spec.weights { axes[wght] = min(max(weight.value, range.lowerBound), range.upperBound) }
            if let range = spec.opticalSizes { axes[opsz] = min(max(Double(size), range.lowerBound), range.upperBound) }
            return (bundled(spec.name, face: face, weight: weight, size: size, axes: axes, text: text), spec.design)
        }
    }

    private static func designed(_ font: UIFont, _ design: UIFontDescriptor.SystemDesign) -> UIFont {
        guard let descriptor = font.fontDescriptor.withDesign(design) else { return font }
        return UIFont(descriptor: descriptor, size: font.pointSize)
    }

    /// The bundled file at its axes; when it lacks Latin letters of `text`, the Latin face of its character that has them.
    private static func bundled(
        _ name: String, face: TextOverlayFont, weight: TextOverlayWeight, size: CGFloat, axes: [NSNumber: Double], text: String
    ) -> UIFont {
        let standIn = { latinFont(ScriptTypeMap.latinStandIn(for: face.character), weight: face.scriptWeight(weight), size: size, text: "").font }
        guard let base = UIFont(name: name, size: size) else { return standIn() }
        var font = base
        if !axes.isEmpty {
            let variation = axes.mapValues { NSNumber(value: $0) }
            let descriptor = base.fontDescriptor.addingAttributes([
                UIFontDescriptor.AttributeName(rawValue: kCTFontVariationAttribute as String): variation,
            ])
            font = UIFont(descriptor: descriptor, size: size)
        }
        return ScriptFontCascade.coversLatin(font, text) ? font : standIn()
    }

    /// An imported face at `weight` (on its weight axis when it has one).
    private static func imported(_ face: CustomFontFace, weight: TextOverlayWeight, size: CGFloat) -> UIFont? {
        guard let base = UIFont(name: face.postScriptName, size: size) else { return nil }
        guard let range = face.weightRange else { return base }
        return UIFont(descriptor: base.fontDescriptor.addingAttributes([
            UIFontDescriptor.AttributeName(rawValue: kCTFontVariationAttribute as String): [
                wght: NSNumber(value: min(max(weight.value, range.lowerBound), range.upperBound)),
            ],
        ]), size: size)
    }
}
