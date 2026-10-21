//
//  SettingsIcon.swift
//  Cue Studio
//

import SwiftUI

/// The icon of a Settings row: one of Cue's own glyphs (`Assets › SettingsIcons`, drawn for Cue on a 24 pt grid, duotone: a soft body, a
/// firm outline and one solid detail of the app's, like the prompter's reading line or the dot of a recording) and the colours of its
/// family: yellow for what a creator records with, violet for the AI, grey for the rest, Cue Pro solid yellow (`Palette.Settings`).
enum SettingsIcon: String {
    case recording, prompter, remote
    case voice, personalize
    case language, notifications, privacy, restore, policy, terms, acknowledgements, version
    case pro

    var image: Image { Image("SettingsIcons/\(rawValue)") }

    var glyph: Color {
        switch self {
        case .recording, .prompter, .remote: Palette.Settings.toolGlyph
        case .voice, .personalize: Palette.Settings.aiGlyph
        case .pro: Palette.Settings.proGlyph
        default: Palette.Settings.generalGlyph
        }
    }

    /// The tile's colour, lighter at the top.
    var tile: LinearGradient {
        let (top, bottom) = switch self {
        case .recording, .prompter, .remote: (Palette.Settings.toolTileTop, Palette.Settings.toolTileBottom)
        case .voice, .personalize: (Palette.Settings.aiTileTop, Palette.Settings.aiTileBottom)
        case .pro: (Palette.Settings.proTileTop, Palette.Settings.proTileBottom)
        default: (Palette.Settings.generalTileTop, Palette.Settings.generalTileBottom)
        }
        return LinearGradient(colors: [top, bottom], startPoint: .top, endPoint: .bottom)
    }
}
