//
//  TextOverlayFont.swift
//  Cue Studio
//

import Foundation

/// Typefaces for words on the video: texts, captions and the cover share one list (`editorFonts`), all bundled under
/// the SIL OFL 1.1 but SF Pro; the system designs before them (classic, rounded, serif, mono) stay for edits that used
/// them. Letters a bundled font lacks (Arabic, Hindi, Thai, CJK; Vietnamese in some) fall back to the system's (`TextFont`).
/// A family the creator imported (`CustomFontRegistry`) is saved as "custom:<family name>", so a video keeps naming it when
/// the font is gone (it draws in SF Pro meanwhile, and in it again once the same family is imported); an earlier version
/// of Cue reads it as SF Pro (`LenientChoice`).
nonisolated struct TextOverlayFont: LenientChoice, CaseIterable, Identifiable, Hashable, Sendable, CustomStringConvertible {
    /// Read in place of a value a newer version of Cue added (`LenientChoice`).
    static let fallback = TextOverlayFont.sfPro

    /// The bundled face's name ("montserrat"), or "custom:<family name>" for an imported one.
    let rawValue: String

    init?(rawValue: String) {
        guard Self.allCases.contains(where: { $0.rawValue == rawValue }) || Self.family(in: rawValue) != nil else { return nil }
        self.rawValue = rawValue
    }

    private init(named name: String) {
        rawValue = name
    }

    static let classic = TextOverlayFont(named: "classic")
    static let rounded = TextOverlayFont(named: "rounded")
    static let serif = TextOverlayFont(named: "serif")
    static let mono = TextOverlayFont(named: "mono")
    static let dmSans = TextOverlayFont(named: "dmSans")
    static let spaceGrotesk = TextOverlayFont(named: "spaceGrotesk")
    static let dmSerif = TextOverlayFont(named: "dmSerif")
    static let sfPro = TextOverlayFont(named: "sfPro")
    /// The faces of the v27 text styles: Orbit, Logbook, Signal, Launch, Nebula and Postcard.
    static let unbounded = TextOverlayFont(named: "unbounded")
    static let instrumentSerif = TextOverlayFont(named: "instrumentSerif")
    static let spaceMono = TextOverlayFont(named: "spaceMono")
    static let anton = TextOverlayFont(named: "anton")
    static let syne = TextOverlayFont(named: "syne")
    static let caveat = TextOverlayFont(named: "caveat")
    /// What creators caption with most (2025–26): Montserrat (Hormozi-style captions), TikTok's own TikTok Sans,
    /// Poppins, Rubik, and Bangers (MrBeast-style comic captions).
    static let montserrat = TextOverlayFont(named: "montserrat")
    static let tiktokSans = TextOverlayFont(named: "tiktokSans")
    static let poppins = TextOverlayFont(named: "poppins")
    static let rubik = TextOverlayFont(named: "rubik")
    static let bangers = TextOverlayFont(named: "bangers")

    /// The bundled and system faces, in the order they were added.
    static let allCases: [TextOverlayFont] = [
        .classic, .rounded, .serif, .mono, .dmSans, .spaceGrotesk, .dmSerif, .sfPro, .unbounded, .instrumentSerif, .spaceMono,
        .anton, .syne, .caveat, .montserrat, .tiktokSans, .poppins, .rubik, .bangers,
    ]

    /// The families Text style, Caption style and the cover's Title offer, each chip drawn in its own face: the caption
    /// favourites first, then the clean sans, the display faces, the serifs, handwriting and mono.
    static let editorFonts: [TextOverlayFont] = [
        .montserrat, .tiktokSans, .poppins, .rubik, .dmSans, .sfPro, .spaceGrotesk, .unbounded, .syne, .anton, .bangers,
        .dmSerif, .instrumentSerif, .caveat, .spaceMono,
    ]

    /// What a picker offers: the creator's imported families first (the newest first), then `editorFonts`; `current` too,
    /// when it is a family that was removed or isn't on this iPhone, so the picker still shows what the text uses.
    static func pickerFonts(including current: TextOverlayFont? = nil) -> [TextOverlayFont] {
        var fonts = CustomFontRegistry.shared.offeredFamilies.map(TextOverlayFont.custom)
        if let current, current.isCustom, !fonts.contains(current) { fonts.insert(current, at: 0) }
        return fonts + editorFonts
    }

    /// An imported family, by its name.
    static func custom(_ family: String) -> TextOverlayFont {
        TextOverlayFont(named: customPrefix + family)
    }

    /// The imported family's name, nil for a bundled face.
    var customFamily: String? { Self.family(in: rawValue) }

    var isCustom: Bool { customFamily != nil }

    /// An imported family that isn't on this iPhone (removed for good, or never imported here): it draws in SF Pro.
    var isMissing: Bool {
        guard let customFamily else { return false }
        return !CustomFontRegistry.shared.has(customFamily)
    }

    /// The weights it comes in: DM Serif Display has only its regular; an imported family, the ones its files have.
    var weights: [TextOverlayWeight] {
        if let customFamily {
            return CustomFontRegistry.shared.weights(of: customFamily) ?? TextOverlayWeight.editorWeights
        }
        switch self {
        case .dmSerif, .instrumentSerif, .anton, .bangers: return [.regular]
        case .spaceMono: return [.bold]
        default: return TextOverlayWeight.editorWeights
        }
    }

    var id: String { rawValue }

    /// Its name, as when it was an enum (the pickers' identifiers, "edit.textFont.montserrat").
    var description: String { rawValue }

    var label: String {
        if let customFamily { return customFamily }
        return Self.labels[rawValue] ?? rawValue
    }

    // MARK: - Private

    private static let customPrefix = "custom:"

    private static func family(in raw: String) -> String? {
        guard raw.hasPrefix(customPrefix) else { return nil }
        let name = String(raw.dropFirst(customPrefix.count))
        return name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : name
    }

    private static var labels: [String: String] {
        [
            "classic": String(localized: "Classic"), "rounded": String(localized: "Rounded"), "serif": String(localized: "Serif"),
            "mono": String(localized: "Mono"), "dmSans": "DM Sans", "spaceGrotesk": "Space Grotesk", "dmSerif": "DM Serif Display",
            "sfPro": "SF Pro", "unbounded": "Unbounded", "instrumentSerif": "Instrument Serif", "spaceMono": "Space Mono",
            "anton": "Anton", "syne": "Syne", "caveat": "Caveat", "montserrat": "Montserrat", "tiktokSans": "TikTok Sans",
            "poppins": "Poppins", "rubik": "Rubik", "bangers": "Bangers",
        ]
    }
}
