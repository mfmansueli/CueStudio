//
//  CaptionTheme.swift
//  Cue Studio
//

import Foundation

/// A caption style of the catalogue: its identity in saved edits. The look it names is read by version
/// (`CaptionStyleSpec.spec(for:version:)`): the first seven keep the looks edits were saved with, and every style has its
/// catalogue look (version 3). Separate identities keep saved TypePreset looks unchanged.
nonisolated enum CaptionTheme: String, LenientChoice, CaseIterable, Identifiable, Sendable {
    /// Read in place of a value a newer version of Cue added (`LenientChoice`).
    static let fallback = CaptionTheme.cue

    case cue, impact, clean, pop, editorial
    /// Added with the complete presets (`CaptionStyleSpec` version 2).
    case educational, interview
    /// Added with the catalogue (version 3).
    case outline, band, glide, spotlight, reveal, bold, comic, punch, paper, mono, lightPill, coral, cyanNight

    /// The catalogue, by group (`CaptionCategory`), in the order Caption style shows it.
    static let catalog: [CaptionTheme] = CaptionCategory.allCases.flatMap(themes(in:))

    /// The styles filed under `category`.
    static func themes(in category: CaptionCategory) -> [CaptionTheme] {
        switch category {
        case .cue: [.cue, .glide, .spotlight, .reveal]
        case .essentials: [.clean, .educational, .outline, .band]
        case .impact: [.impact, .bold, .comic, .punch]
        case .editorial: [.editorial, .paper, .interview, .mono]
        case .colorful: [.pop, .lightPill, .coral, .cyanNight]
        }
    }

    var id: String { rawValue }

    var category: CaptionCategory {
        CaptionCategory.allCases.first { Self.themes(in: $0).contains(self) } ?? .cue
    }

    /// Whether edits could pick it before the catalogue (its earlier readings exist).
    var existedBeforeCatalog: Bool {
        switch self {
        case .cue, .impact, .clean, .pop, .editorial, .educational, .interview: true
        default: false
        }
    }

    var label: String {
        switch self {
        case .cue: String(localized: "Cue")
        case .impact: String(localized: "Condensed")
        case .clean: String(inInterfaceLanguage: LocalizedStringResource("Clean caption style", defaultValue: "Clean"))
        case .pop: String(localized: "Violet")
        case .editorial: String(localized: "Serif")
        case .educational: String(localized: "Dark box")
        case .interview: String(localized: "Interview")
        case .outline: String(localized: "Outline")
        case .band: String(localized: "Band")
        case .glide: String(localized: "Glide")
        case .spotlight: String(localized: "Spotlight")
        case .reveal: String(localized: "Reveal")
        case .bold: String(localized: "Bold")
        case .comic: String(localized: "Comic")
        // Not the zoom effect named Punch: a caption style's name.
        case .punch: String(inInterfaceLanguage: LocalizedStringResource("captionStyle.punch", defaultValue: "Punch"))
        case .paper: String(localized: "Paper")
        case .mono: String(localized: "Mono")
        case .lightPill: String(localized: "Light pill")
        case .coral: String(localized: "Coral")
        case .cyanNight: String(localized: "Cyan night")
        }
    }

    /// What the style looks like, in a few words: read by VoiceOver with the name.
    var summary: String {
        switch self {
        case .cue: String(localized: "Bold sans, a yellow box on the word being said")
        case .impact: String(localized: "Condensed capitals, thick outline, a quick punch")
        case .clean: String(localized: "Simple type with a dark halo, fades in")
        case .pop: String(localized: "Rounded heavy type on violet lines, pops in")
        case .editorial: String(localized: "Display serif on a dark box, slow fade")
        case .educational: String(localized: "Clear type on a dark box, the word said in yellow")
        case .interview: String(localized: "Sober type on a soft box, still lines")
        case .outline: String(localized: "Heavy type with a thick outline, pops in")
        case .band: String(localized: "Spaced capitals on square bands, rises in")
        case .glide: String(localized: "Capitals with a box that slides word to word")
        case .spotlight: String(localized: "Heavy type, the word said grows in lime")
        case .reveal: String(localized: "Words appear as they are said")
        case .bold: String(localized: "Heavy capitals, the word said pops in yellow")
        case .comic: String(localized: "Comic capitals with a thick outline, the word said pops")
        case .punch: String(localized: "Wide capitals, a red pill on the word said")
        case .paper: String(localized: "Serif on cream paper, rises in")
        case .mono: String(localized: "Typewriter letters on black, word by word")
        case .lightPill: String(localized: "Dark type on white pills, the word said in blue")
        case .coral: String(localized: "Dark type on coral, a dark box on the word said")
        case .cyanNight: String(localized: "Cyan capitals on a dark box, rises in")
        }
    }

    /// The first reading of the preset (`CaptionStyleSpec`); what a new look is drawn with is
    /// `CaptionSettings.spec`.
    private var firstReading: CaptionStyleSpec { CaptionStyleSpec.spec(for: self, version: ReadingVersion.captionStyle.first) }

    var fontName: String { firstReading.fontName }

    var fontWeight: Double { firstReading.fontWeight }

    var defaultAccent: CaptionAccent { firstReading.defaultAccent }
}
