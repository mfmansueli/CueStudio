//
//  CustomFontInspector.swift
//  Cue Studio
//

import CoreText
import Foundation

/// Reads a font file before Cue keeps it: TrueType, OpenType or a collection of them, whole (Core Text builds every face, each
/// has a 'head' table and letters), no larger than `maximumBytes`, and not a font this iPhone already has under the same
/// PostScript name (Core Text would refuse to register it, and the text would quietly draw in the other one). Each face comes
/// back with its family, style, weight (the OS/2 table's, like CSS) and, for a variable font, its weight axis.
nonisolated enum CustomFontInspector {
    /// Larger than any text face needs (a full CJK family is about 20 MB).
    static let maximumBytes = 40 * 1024 * 1024

    struct Face: Equatable, Sendable {
        var postScriptName: String
        var familyName: String
        var styleName: String
        var weight: Double
        var isItalic: Bool
        var weightRange: ClosedRange<Double>?
    }

    enum Problem: Error, Equatable, Sendable {
        /// Not a font Core Text reads (a WOFF from a website, a renamed file, a damaged download).
        case notAFont
        /// Read, but a face is broken or has no letters (an icon font).
        case damaged
        case tooLarge
        /// The iPhone or Cue already has a font with this PostScript name.
        case alreadyInstalled(String)

        var message: String {
            switch self {
            case .notAFont: String(localized: "This file isn’t a font Cue can use · TTF or OTF")
            case .damaged: String(localized: "This font is damaged or has no letters")
            case .tooLarge: String(localized: "This font file is too large")
            case .alreadyInstalled(let name): String(localized: "\(name) is already on this iPhone")
            }
        }
    }

    /// The faces in `data`; `isInstalled` says whether a PostScript name is already taken (by the system, a bundled font, or a
    /// family imported before: a re-import of the same file is the caller's to recognise first).
    static func inspect(_ data: Data, isInstalled: (String) -> Bool) throws(Problem) -> [Face] {
        guard data.count <= maximumBytes else { throw .tooLarge }
        guard let descriptors = CTFontManagerCreateFontDescriptorsFromData(data as CFData) as? [CTFontDescriptor], !descriptors.isEmpty else {
            throw .notAFont
        }
        var faces: [Face] = []
        for descriptor in descriptors {
            let font = CTFontCreateWithFontDescriptor(descriptor, 24, nil)
            let postScriptName = CTFontCopyPostScriptName(font) as String
            let familyName = (CTFontCopyFamilyName(font) as String).trimmingCharacters(in: .whitespacesAndNewlines)
            guard !postScriptName.isEmpty, !familyName.isEmpty, CTFontCopyTable(font, CTFontTableTag(kCTFontTableHead), []) != nil,
                  CTFontGetGlyphCount(font) > 1, hasLetters(font) else { throw .damaged }
            guard !isInstalled(postScriptName) else { throw .alreadyInstalled(familyName) }
            let style = (CTFontCopyName(font, kCTFontStyleNameKey) as String?) ?? String(localized: "Regular")
            let italic = CTFontGetSymbolicTraits(font).contains(.traitItalic)
            faces.append(Face(
                postScriptName: postScriptName, familyName: familyName, styleName: style, weight: weight(of: font),
                isItalic: italic, weightRange: weightAxis(of: font)
            ))
        }
        return faces
    }

    /// The face's weight: the OS/2 table's usWeightClass (100 to 900), else read from its traits.
    static func weight(of font: CTFont) -> Double {
        if let table = CTFontCopyTable(font, CTFontTableTag(kCTFontTableOS2), []) as Data?, table.count >= 6 {
            let value = Double(UInt16(table[table.startIndex + 4]) << 8 | UInt16(table[table.startIndex + 5]))
            if (1...1000).contains(value) { return value }
        }
        let traits = CTFontCopyTraits(font) as NSDictionary
        let trait = (traits[kCTFontWeightTrait] as? NSNumber)?.doubleValue ?? 0
        // UIFont.Weight's steps: -0.8 thin … 0 regular … 0.62 black.
        let steps: [(Double, Double)] = [(-0.8, 100), (-0.6, 200), (-0.4, 300), (0, 400), (0.23, 500), (0.3, 600), (0.4, 700), (0.56, 800), (0.62, 900)]
        return steps.min { abs($0.0 - trait) < abs($1.0 - trait) }?.1 ?? 400
    }

    /// The range of a variable font's weight axis ('wght'), nil when it has none.
    static func weightAxis(of font: CTFont) -> ClosedRange<Double>? {
        guard let axes = CTFontCopyVariationAxes(font) as? [[CFString: Any]] else { return nil }
        let tag = 0x7767_6874
        guard let axis = axes.first(where: { ($0[kCTFontVariationAxisIdentifierKey] as? NSNumber)?.intValue == tag }),
              let low = (axis[kCTFontVariationAxisMinimumValueKey] as? NSNumber)?.doubleValue,
              let high = (axis[kCTFontVariationAxisMaximumValueKey] as? NSNumber)?.doubleValue, low < high else { return nil }
        return low...high
    }

    /// Whether the face draws letters or digits at all (an icon font doesn't).
    private static func hasLetters(_ font: CTFont) -> Bool {
        ["A", "a", "0", "А", "あ", "가", "ا"].contains { letter in
            let characters = Array(letter.utf16)
            var glyphs = [CGGlyph](repeating: 0, count: characters.count)
            return CTFontGetGlyphsForCharacters(font, characters, &glyphs, characters.count)
        }
    }
}
