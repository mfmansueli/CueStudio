//
//  CaptionTheme.swift
//  Cue Studio
//

import Foundation

/// The video caption collection. Separate identities keep saved TypePreset looks unchanged.
nonisolated enum CaptionTheme: String, Codable, CaseIterable, Identifiable, Sendable {
    case cue, impact, clean, pop, editorial
    /// Added with the complete presets (`CaptionStyleSpec` version 2).
    case educational, interview

    /// The presets Caption style offers, in order. Clean stays for edits that picked it, and shows
    /// only while it is the one in use: Interview is its sober successor.
    static let catalog: [CaptionTheme] = [.cue, .educational, .interview, .impact, .pop, .editorial]

    var id: String { rawValue }

    var label: String {
        switch self {
        case .cue: String(localized: "Cue")
        case .impact: String(localized: "Impact")
        case .clean: String(inInterfaceLanguage: LocalizedStringResource("Clean caption style", defaultValue: "Clean"))
        case .pop: String(localized: "Pop")
        case .editorial: String(localized: "Editorial")
        case .educational: String(localized: "Educational")
        case .interview: String(localized: "Interview")
        }
    }

    /// The first reading of the preset (`CaptionStyleSpec`); what a new look is drawn with is
    /// `CaptionSettings.spec`.
    private var firstReading: CaptionStyleSpec { CaptionStyleSpec.spec(for: self, version: 1) }

    var fontName: String { firstReading.fontName }

    var fontWeight: Double { firstReading.fontWeight }

    var defaultAccent: CaptionAccent { firstReading.defaultAccent }
}
