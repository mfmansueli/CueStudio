//
//  TextOverlayFont+Character.swift
//  Cue Studio
//

import Foundation

/// What kind of face each family is (`TypeCharacter`), for its likeness in another script.
nonisolated extension TextOverlayFont {
    var character: TypeCharacter {
        if let pack = pack { return pack.character }
        switch rawValue {
        case "montserrat", "poppins": return .geometric
        case "rubik", "rounded": return .rounded
        case "anton": return .condensed
        case "unbounded", "syne": return .wide
        case "bangers": return .comic
        case "dmSerif", "instrumentSerif", "serif": return .serif
        case "caveat": return .handwritten
        case "spaceMono", "mono": return .mono
        default: return .sans
        }
    }

    /// The weight another script's face is drawn at for this family at `weight`: as heavy as the family looks in its one cut.
    func scriptWeight(_ weight: TextOverlayWeight) -> TextOverlayWeight {
        switch rawValue {
        case "anton", "bangers": .heavy
        case "dmSerif", "spaceMono": .bold
        default: weight
        }
    }

    /// The character of a caption preset's own font (its registered name), for the presets that name a file, not a family.
    static func character(ofFontNamed name: String) -> TypeCharacter {
        if name.hasPrefix("Anton") { return .condensed }
        if name.hasPrefix("Poppins") || name.hasPrefix("Montserrat") { return .geometric }
        if name.hasPrefix("DMSerif") || name.hasPrefix("InstrumentSerif") { return .serif }
        if name.hasPrefix("SpaceMono") { return .mono }
        return .sans
    }
}
