//
//  CaptionTheme.swift
//  Cue Studio
//

import Foundation

/// The video caption collection. Separate identities keep saved TypePreset looks unchanged.
nonisolated enum CaptionTheme: String, Codable, CaseIterable, Identifiable, Sendable {
    case cue, impact, clean, pop, editorial

    var id: String { rawValue }

    var label: String {
        switch self {
        case .cue: String(localized: "Cue")
        case .impact: String(localized: "Impact")
        case .clean: String(inInterfaceLanguage: LocalizedStringResource("Clean caption style", defaultValue: "Clean"))
        case .pop: String(localized: "Pop")
        case .editorial: String(localized: "Editorial")
        }
    }

    var fontName: String {
        switch self {
        case .cue: "SpaceGrotesk-Light" // Variable font's registered PostScript name; wght selects Bold.
        case .impact: "Anton-Regular"
        case .clean: "Inter-Regular"
        case .pop: "Poppins-ExtraBold"
        case .editorial: "Manrope-Regular"
        }
    }

    var fontWeight: Double {
        switch self {
        case .cue, .editorial: 700
        case .clean: 600
        case .pop: 800
        case .impact: 400 // Anton's single cut is already heavy and condensed.
        }
    }

    var defaultAccent: CaptionAccent {
        switch self {
        case .cue, .clean, .pop: .yellow
        case .impact: .lime
        case .editorial: .peach
        }
    }
}
