//
//  ScriptFontCascade.swift
//  Cue Studio
//

import CoreText
import os
import UIKit

/// The one place a face for words on the video learns to draw every script (`TextFont`, `CaptionFont`, the cover), so the
/// preview, the export and the panels' cards draw the same letters. The face draws what it has; Core Text takes the rest
/// letter by letter from a cascade list, in this order:
/// 1. for each script in the words (Japanese, Chinese, Korean, Arabic, Hindi, Thai), the library family with the face's
///    character (`ScriptTypeMap`) when its file is here (`FontPackRegistry`), then the system's faces of that script at the
///    same weight, which draw while the download runs;
/// 2. the system font at the weight (and its design), for anything else (Cyrillic, Greek, Hebrew, emoji, symbols).
/// "Day 1 の朝" keeps "Day 1" in the style's face and draws "の朝" in the Japanese one. Latin letters the face lacks (Vietnamese
/// in DM Sans) are a different matter: a word must not mix two faces, so the whole text goes to a Latin face of the same
/// character that has them (`ScriptTypeMap.latinStandIn`).
nonisolated enum ScriptFontCascade {
    /// `base` drawing `text` with every script in it: the cascade above. `character` and `weight` pick the other scripts' faces.
    /// `systemFaces` false leaves the system's own faces to the system font (a line set on it, `setsOnSystem`): only a
    /// library family that is here goes before it.
    static func font(
        _ base: UIFont, character: TypeCharacter, weight: TextOverlayWeight, text: String, design: UIFontDescriptor.SystemDesign = .default,
        systemFaces: Bool = true, registry: FontPackRegistry = .shared
    ) -> UIFont {
        let size = base.pointSize
        var cascade: [UIFontDescriptor] = []
        for script in WritingScript.scripts(in: text, han: registry.hanReading) {
            cascade += descriptors(for: script, character: character, weight: weight, size: size, systemFaces: systemFaces, registry: registry)
        }
        cascade.append(system(size: size, weight: weight, design: design).fontDescriptor)
        let descriptor = base.fontDescriptor.addingAttributes([
            UIFontDescriptor.AttributeName(rawValue: kCTFontCascadeListAttribute as String): cascade,
        ])
        return UIFont(descriptor: descriptor, size: size)
    }

    /// A library family as the face itself (a text in "pack:<id>"): its file when here, else the system's face of its script
    /// with its character; the cascade after it as for any face.
    static func font(pack: FontPack, weight: TextOverlayWeight, size: CGFloat, text: String, registry: FontPackRegistry = .shared) -> UIFont {
        let base = face(of: pack, weight: weight, size: size, registry: registry)
            ?? ScriptTypeMap.systemFaces(for: pack.character, in: pack.script, weight: weight).lazy.compactMap { named($0, size: size) }.first
            ?? system(size: size, weight: weight, design: .default)
        return font(base, character: pack.character, weight: weight, text: text, registry: registry)
    }

    /// Whether `font` has every Latin letter of `text` (accents included); other scripts don't count: the cascade draws them.
    static func coversLatin(_ font: UIFont, _ text: String) -> Bool {
        let latin = text.unicodeScalars.filter(isLatinLetter)
        guard !latin.isEmpty else { return true }
        let characters = Array(String(String.UnicodeScalarView(latin)).utf16)
        var glyphs = [CGGlyph](repeating: 0, count: characters.count)
        return CTFontGetGlyphsForCharacters(font as CTFont, characters, &glyphs, characters.count)
    }

    /// Whether `font` draws none of `text` itself: no Latin letter to keep and some letters it lacks (a line all in Arabic in
    /// DM Serif). Such a line is set on the system font with the system's own faces, as Cue always set it, so a video made
    /// before the libraries keeps its line height and its look; the library family of the style's character goes first once
    /// it is here (a video using it asks for it: `FontPackNeeds`).
    static func setsOnSystem(_ font: UIFont, _ text: String) -> Bool {
        guard !text.unicodeScalars.contains(where: isLatinLetter) else { return false }
        let characters = Array(String(String.UnicodeScalarView(text.unicodeScalars.filter { !CharacterSet.whitespacesAndNewlines.contains($0) })).utf16)
        guard !characters.isEmpty else { return false }
        var glyphs = [CGGlyph](repeating: 0, count: characters.count)
        return !CTFontGetGlyphsForCharacters(font as CTFont, characters, &glyphs, characters.count)
    }

    /// The system font at a weight, in a design.
    static func system(size: CGFloat, weight: TextOverlayWeight, design: UIFontDescriptor.SystemDesign) -> UIFont {
        let font = UIFont.systemFont(ofSize: size, weight: TextFont.uiWeight(weight))
        guard design != .default, let descriptor = font.fontDescriptor.withDesign(design) else { return font }
        return UIFont(descriptor: descriptor, size: size)
    }

    // MARK: - Private

    private static func descriptors(
        for script: WritingScript, character: TypeCharacter, weight: TextOverlayWeight, size: CGFloat, systemFaces: Bool,
        registry: FontPackRegistry
    ) -> [UIFontDescriptor] {
        var list: [UIFontDescriptor] = []
        if let id = ScriptTypeMap.packID(for: character, in: script), let pack = FontPackManifest.bundled.pack(id),
           let face = face(of: pack, weight: weight, size: size, registry: registry) {
            list.append(face.fontDescriptor)
        }
        for name in ScriptTypeMap.systemFaces(for: character, in: script, weight: weight) where systemFaces && exists(name) {
            list.append(UIFontDescriptor(name: name, size: size))
        }
        return list
    }

    /// The library file that draws `pack` at `weight`, when it is here (a variable file at the weight on its axis).
    private static func face(of pack: FontPack, weight: TextOverlayWeight, size: CGFloat, registry: FontPackRegistry) -> UIFont? {
        guard let match = registry.face(of: pack, weight: weight), let font = UIFont(name: match.postScriptName, size: size) else { return nil }
        guard let range = match.file.weightRange else { return font }
        let value = min(max(weight.value, range.lowerBound), range.upperBound)
        let descriptor = font.fontDescriptor.addingAttributes([
            UIFontDescriptor.AttributeName(rawValue: kCTFontVariationAttribute as String): [wght: NSNumber(value: value)],
        ])
        return UIFont(descriptor: descriptor, size: size)
    }

    private static let wght: NSNumber = 0x7767_6874

    private static func named(_ name: String, size: CGFloat) -> UIFont? {
        exists(name) ? UIFont(name: name, size: size) : nil
    }

    /// Whether this iPhone has a face of that name (asked once per name).
    private static func exists(_ name: String) -> Bool {
        if let known = known.withLock({ $0[name] }) { return known }
        let found = UIFont(name: name, size: 12) != nil
        known.withLock { $0[name] = found }
        return found
    }

    private static let known = OSAllocatedUnfairLock<[String: Bool]>(initialState: [:])

    /// Latin letters and the marks that sit on them (Vietnamese stacks two): Basic Latin to Latin Extended-B, IPA, the
    /// combining marks and Latin Extended Additional.
    private static func isLatinLetter(_ scalar: Unicode.Scalar) -> Bool {
        switch scalar.value {
        case 0x41...0x5A, 0x61...0x7A, 0xC0...0x24F, 0x300...0x36F, 0x1E00...0x1EFF: scalar.value != 0xD7 && scalar.value != 0xF7
        default: false
        }
    }
}
