//
//  TextEffectKind.swift
//  Cue Studio
//

import Foundation

/// One of the finished looks a text can wear on top of its type (Text style › Styles › Animated): a material, light and depth
/// drawn on the creator's own words, with a way in, a still time to be read and a way out. Each one is drawn by
/// `TextEffectPainter` and placed by `TextEffectComposer` the same in the preview, at any moment of the timeline and in
/// the export.
nonisolated enum TextEffectKind: String, LenientChoice, CaseIterable, Identifiable, Sendable {
    /// Read in place of a kind a newer version of Cue added (`LenientChoice`): the quietest finish.
    static let fallback = TextEffectKind.sheen

    /// Gold (or rose gold, silver) with tonal bands, a slight bevel, a glint crossing it and a few short sparkles.
    case gold
    /// Letters arriving in a coordinated wave (rise and tilt), settling into a still line.
    case wave
    /// Chunky letters with simulated depth, one outline around face and depth, a springy pop in.
    case pop3D
    /// A legible bright core in a soft halo, lit letter after letter, without flashes.
    case neon
    /// Word by word out of a band behind each line, precise like a magazine's motion graphics.
    case headline
    /// A clean, quiet finish a band of light crosses once.
    case sheen

    var id: String { rawValue }

    var label: String {
        switch self {
        case .gold: String(localized: "Gold metal", comment: "Text effect: letters in gold metal")
        case .wave: String(localized: "Type wave", comment: "Text effect: letters arriving in a wave")
        case .pop3D: String(localized: "Pop 3D", comment: "Text effect: chunky letters with depth that pop in")
        case .neon: String(localized: "Neon", comment: "Text effect: letters lit like a neon sign")
        case .headline: String(localized: "Editorial reveal", comment: "Text effect: words revealed over a band, like a magazine")
        case .sheen: String(localized: "Elegant sheen", comment: "Text effect: a clean finish a band of light crosses")
        }
    }

    /// What it looks like, for VoiceOver and the card's hint.
    var summary: String {
        switch self {
        case .gold: String(localized: "Gold metal with a glint and short sparkles")
        case .wave: String(localized: "Letters arrive in a wave, then hold still")
        case .pop3D: String(localized: "Bold letters with depth that pop in")
        case .neon: String(localized: "A bright tube in a soft halo that lights up")
        case .headline: String(localized: "Words rise word by word over a band")
        case .sheen: String(localized: "A clean finish a band of light crosses")
        }
    }

    /// The effect moves whole words, never letters: a reveal reads by word.
    var movesWords: Bool { self == .headline }

    /// How long its way in takes by default, and the range Speed offers.
    var defaultDuration: TimeInterval {
        switch self {
        case .gold: 1.1
        case .wave: 1.2
        case .pop3D: 0.8
        case .neon: 0.9
        case .headline: 1.0
        case .sheen: 1.2
        }
    }

    static let durationRange: ClosedRange<TimeInterval> = 0.4...2.4

    var defaultIntensity: Double {
        switch self {
        case .gold: 0.6
        case .wave: 0.5
        case .pop3D: 0.65
        case .neon: 0.6
        case .headline: 1
        case .sheen: 0.6
        }
    }

    /// What its strength slider changes, by name.
    var intensityLabel: String {
        switch self {
        case .gold: String(localized: "Shine", comment: "Gold text effect: how strongly the metal shines")
        case .wave: String(localized: "Wave height", comment: "Wave text effect: how far the letters travel")
        case .pop3D: String(localized: "Depth", comment: "Pop 3D text effect: how deep the letters are")
        case .neon: String(localized: "Glow", comment: "Neon text effect: how far the light spreads")
        case .headline: String(localized: "Band height", comment: "Headline text effect: from an underline to a full band")
        case .sheen: String(localized: "Sheen", comment: "Sheen text effect: how bright the band of light is")
        }
    }

    /// The directions its motion (or depth) can take, the first one the default; empty when direction means nothing.
    var directions: [TextEffectDirection] {
        switch self {
        case .gold, .sheen: [.start, .end]
        case .wave: [.start, .middle, .end]
        case .pop3D: [.right, .down, .left]
        case .neon: [.start, .end]
        case .headline: [.up, .down]
        }
    }

    /// Whether Color offers a second color (the depth's, the band's).
    var usesAccent: Bool { self == .pop3D || self == .headline }

    /// The second color's name in Color.
    var accentLabel: String {
        switch self {
        case .headline: String(localized: "Band color", comment: "Headline text effect: the color of the band behind the words")
        default: String(localized: "Depth color", comment: "Pop 3D text effect: the color of the letters' depth")
        }
    }

    var defaultAccent: OverlayColor {
        switch self {
        case .pop3D: .red
        case .headline: .paper
        default: .offBlack
        }
    }

    /// Whether Color offers the metal's tone instead of a text color.
    var usesTone: Bool { self == .gold }

    /// Whether the text's own color colors it (not for metal, which has its tone).
    var usesTextColor: Bool { self != .gold }
}
