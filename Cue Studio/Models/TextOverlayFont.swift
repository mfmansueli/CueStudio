//
//  TextOverlayFont.swift
//  Cue Studio
//

import Foundation

/// Typefaces for texts on the video. The editor offers the bundled DM Sans, Space Grotesk and DM
/// Serif Display (SIL OFL 1.1) and SF Pro; the system designs before them (classic, rounded, serif,
/// mono) stay for edits that used them. Letters a bundled font lacks (Arabic, Hindi, Thai, CJK…)
/// fall back to the system's (`TextFont`).
nonisolated enum TextOverlayFont: String, Codable, CaseIterable, Identifiable, Sendable {
    case classic, rounded, serif, mono
    case dmSans, spaceGrotesk, dmSerif, sfPro
    /// The faces of the v27 text styles: Orbit, Logbook, Signal, Launch, Nebula and Postcard.
    case unbounded, instrumentSerif, spaceMono, anton, syne, caveat

    /// The families Text style offers, each chip drawn in its own face.
    static let editorFonts: [TextOverlayFont] = [
        .unbounded, .instrumentSerif, .spaceMono, .anton, .syne, .spaceGrotesk, .caveat, .dmSans, .dmSerif, .sfPro,
    ]

    /// The weights it comes in: DM Serif Display has only its regular.
    var weights: [TextOverlayWeight] {
        switch self {
        case .dmSerif, .instrumentSerif, .anton: [.regular]
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
        }
    }
}
