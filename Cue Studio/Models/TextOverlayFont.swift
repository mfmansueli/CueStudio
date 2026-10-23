//
//  TextOverlayFont.swift
//  Cue Studio
//

import Foundation

/// Typefaces for words on the video: texts, captions and the cover share one list (`editorFonts`), all bundled under
/// the SIL OFL 1.1 but SF Pro; the system designs before them (classic, rounded, serif, mono) stay for edits that used
/// them. Letters a bundled font lacks (Arabic, Hindi, Thai, CJK; Vietnamese in some) fall back to the system's (`TextFont`).
nonisolated enum TextOverlayFont: String, Codable, CaseIterable, Identifiable, Sendable {
    case classic, rounded, serif, mono
    case dmSans, spaceGrotesk, dmSerif, sfPro
    /// The faces of the v27 text styles: Orbit, Logbook, Signal, Launch, Nebula and Postcard.
    case unbounded, instrumentSerif, spaceMono, anton, syne, caveat
    /// What creators caption with most (2025–26): Montserrat (Hormozi-style captions), TikTok's own TikTok Sans,
    /// Poppins, Rubik, and Bangers (MrBeast-style comic captions).
    case montserrat, tiktokSans, poppins, rubik, bangers

    /// The families Text style, Caption style and the cover's Title offer, each chip drawn in its own face: the caption
    /// favourites first, then the clean sans, the display faces, the serifs, handwriting and mono.
    static let editorFonts: [TextOverlayFont] = [
        .montserrat, .tiktokSans, .poppins, .rubik, .dmSans, .sfPro, .spaceGrotesk, .unbounded, .syne, .anton, .bangers,
        .dmSerif, .instrumentSerif, .caveat, .spaceMono,
    ]

    /// The weights it comes in: DM Serif Display has only its regular.
    var weights: [TextOverlayWeight] {
        switch self {
        case .dmSerif, .instrumentSerif, .anton, .bangers: [.regular]
        case .spaceMono: [.bold]
        default: TextOverlayWeight.editorWeights
        }
    }

    var id: String { rawValue }

    var label: String {
        switch self {
        case .classic: String(localized: "Classic")
        case .rounded: String(localized: "Rounded")
        case .serif: String(localized: "Serif")
        case .mono: String(localized: "Mono")
        case .dmSans: "DM Sans"
        case .spaceGrotesk: "Space Grotesk"
        case .dmSerif: "DM Serif Display"
        case .sfPro: "SF Pro"
        case .unbounded: "Unbounded"
        case .instrumentSerif: "Instrument Serif"
        case .spaceMono: "Space Mono"
        case .anton: "Anton"
        case .syne: "Syne"
        case .caveat: "Caveat"
        case .montserrat: "Montserrat"
        case .tiktokSans: "TikTok Sans"
        case .poppins: "Poppins"
        case .rubik: "Rubik"
        case .bangers: "Bangers"
        }
    }
}
