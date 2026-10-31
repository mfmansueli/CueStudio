//
//  ScriptTypeMap.swift
//  Cue Studio
//

import Foundation

/// Which face draws a script's words in place of a Latin face, by the Latin face's character (`TypeCharacter`), so a caption
/// style or a text keeps its personality in every language: Anton's impact is Dela Gothic One in Japanese and Lalezar in
/// Arabic, Caveat's hand is Yomogi and Aref Ruqaa. Two layers: a family of the script's library (downloaded when a video
/// needs it), and the system's own faces of the script at the same weight, which draw at once and while the download runs.
/// Latin letters a face lacks (Vietnamese in DM Sans, Poppins, Syne…) are drawn by a Latin face of the same character that
/// has them (`latinStandIn`), the whole word in one face.
nonisolated enum ScriptTypeMap {
    /// The library family (`FontPack.id`) with `character` in `script`; nil where the system's face is the closest.
    static func packID(for character: TypeCharacter, in script: WritingScript) -> String? {
        table[script]?[character] ?? nil
    }

    /// The system faces (PostScript names) that draw `script` closest to `character` at `weight`, best first. The system font
    /// at the weight comes after them, for whatever else the words hold.
    static func systemFaces(for character: TypeCharacter, in script: WritingScript, weight: TextOverlayWeight) -> [String] {
        let heavy = weight.value >= 700
        let cut = weight.value >= 600 ? "Semibold" : weight == .medium ? "Medium" : "Regular"
        switch script {
        case .japanese:
            return japanese(character, weight: weight)
        case .chineseSimplified:
            return ["PingFangSC-\(cut)"]
        case .chineseTraditional:
            return ["PingFangTC-\(cut)"]
        case .korean:
            return [korean(weight)]
        case .arabic:
            // SF Arabic, the system font's own, at the weight (the cascade's last entry): what Arabic drew in before the
            // libraries, so a video made then keeps its look until a library family arrives.
            return []
        case .devanagari:
            // Poppins, in the app, draws Devanagari: the geometric faces keep it.
            if character == .geometric { return [poppins(weight), heavy ? "KohinoorDevanagari-Semibold" : "KohinoorDevanagari-Regular"] }
            return ["KohinoorDevanagari-\(cut)"]
        case .thai:
            return [heavy ? "Thonburi-Bold" : "Thonburi"]
        }
    }

    /// A Latin face of `character` that draws every Latin letter Cue's languages write (Vietnamese included), for a face that
    /// lacks some of a text's letters.
    static func latinStandIn(for character: TypeCharacter) -> TextOverlayFont {
        switch character {
        case .sans: .tiktokSans
        case .geometric: .montserrat
        case .rounded, .handwritten: .rounded
        case .condensed: .anton
        case .wide: .unbounded
        case .comic: .bangers
        case .serif: .serif
        case .mono: .spaceMono
        }
    }

    // MARK: - Private

    /// Hiragino: Mincho for a serif, Maru Gothic for a light rounded face, the gothic at the weight for the rest.
    private static func japanese(_ character: TypeCharacter, weight: TextOverlayWeight) -> [String] {
        if character == .serif { return [weight.value >= 600 ? "HiraMinProN-W6" : "HiraMinProN-W3"] }
        let gothic = switch weight {
        case .regular: "HiraginoSans-W3"
        case .medium: "HiraginoSans-W5"
        case .semibold: "HiraginoSans-W6"
        case .bold: "HiraginoSans-W7"
        case .heavy: "HiraginoSans-W8"
        }
        return character == .rounded && weight.value < 700 ? ["HiraMaruProN-W4", gothic] : [gothic]
    }

    /// Apple SD Gothic Neo, which has every weight.
    private static func korean(_ weight: TextOverlayWeight) -> String {
        switch weight {
        case .regular: "AppleSDGothicNeo-Regular"
        case .medium: "AppleSDGothicNeo-Medium"
        case .semibold: "AppleSDGothicNeo-SemiBold"
        case .bold: "AppleSDGothicNeo-Bold"
        case .heavy: "AppleSDGothicNeo-Heavy"
        }
    }

    private static func poppins(_ weight: TextOverlayWeight) -> String {
        switch weight {
        case .regular: "Poppins-Regular"
        case .medium: "Poppins-Medium"
        case .semibold, .bold: "Poppins-Bold"
        case .heavy: "Poppins-ExtraBold"
        }
    }

    /// Script × character → library family. Chinese and Korean plain sans stay the system's (PingFang, Apple SD Gothic Neo:
    /// every weight, nothing to download); the geometric Devanagari is Poppins itself.
    private static let table: [WritingScript: [TypeCharacter: String?]] = [
        .japanese: [
            .sans: "zenkakugothicnew", .geometric: "zenkakugothicnew", .rounded: "mplusrounded1c", .condensed: "delagothicone",
            .wide: "mochiypopone", .comic: "reggaeone", .serif: "zenoldmincho", .handwritten: "yomogi", .mono: "mplus1code",
        ],
        .chineseSimplified: [
            .sans: nil, .geometric: nil, .rounded: "zcoolkuaile", .condensed: "zcoolqingkehuangyou", .wide: nil,
            .comic: "zcoolkuaile", .serif: "zcoolxiaowei", .handwritten: "longcang", .mono: nil,
        ],
        .chineseTraditional: [
            .sans: nil, .geometric: nil, .rounded: "huninn", .condensed: nil, .wide: nil, .comic: "huninn", .serif: "notoseriftc",
            .handwritten: "iansui", .mono: nil,
        ],
        .korean: [
            .sans: nil, .geometric: nil, .rounded: "jua", .condensed: "dohyeon", .wide: "blackhansans", .comic: "bagelfatone",
            .serif: "nanummyeongjo", .handwritten: "nanumpenscript", .mono: nil,
        ],
        .arabic: [
            .sans: "cairo", .geometric: "reemkufi", .rounded: "lemonada", .condensed: "changa", .wide: "lalezar", .comic: "marhey",
            .serif: "amiri", .handwritten: "arefruqaa", .mono: nil,
        ],
        .devanagari: [
            .sans: "mukta", .geometric: nil, .rounded: "baloo2", .condensed: "teko", .wide: "yatraone", .comic: "yatraone",
            .serif: "rozhaone", .handwritten: "kalam", .mono: nil,
        ],
        .thai: [
            .sans: "kanit", .geometric: "prompt", .rounded: "mitr", .condensed: "kanit", .wide: "prompt", .comic: "mali",
            .serif: "trirong", .handwritten: "sriracha", .mono: "chakrapetch",
        ],
    ]
}
