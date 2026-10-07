//
//  SkyDensity.swift
//  Cue Studio
//

import Foundation

/// Which starry sky the browse screens have (Personalize › Starry sky): Off, Serene, Adrift or Interstellar. Serene is the default (the owner's call,
/// 6/10/2026; the creator changes it in Settings). Adrift has everything: the drifting stars, the nebulae, the small twinkling stars, the
/// comet and an astronaut floating in zero gravity. Serene is only the drifting stars and the nebulae (nothing twinkles, no comet).
/// Interstellar is deep space: Adrift's stars and twinkles in the colours of a galaxy (blue, magenta and teal nebulae, a Milky Way band, a
/// darker night), with a spaceship that crosses instead of the comet. Off draws no sky at all. Serene, Adrift and Interstellar were Calm, Lively and
/// Galactic before the owner renamed them on 6/10/2026; a choice saved under the old names still reads (`init(saved:)`).
nonisolated enum SkyDensity: String, CaseIterable, Identifiable, Sendable {
    case off, serene, adrift, interstellar

    /// The sky saved in the preferences: the current raw values, and the names the skies had before (calm, lively, galactic), so a creator's
    /// choice carries over. Nil for anything else.
    init?(saved value: String) {
        switch value {
        case "calm": self = .serene
        case "lively": self = .adrift
        case "galactic": self = .interstellar
        default: self.init(rawValue: value)
        }
    }

    var id: String { rawValue }

    /// The position on its four steps.
    var step: Int { Self.allCases.firstIndex(of: self) ?? 1 }

    /// How many twinkling stars a screen has: 14 at Adrift and Interstellar (`motion/README.md`), none at Serene.
    var twinkleCount: Int {
        switch self {
        case .off, .serene: 0
        case .adrift, .interstellar: 14
        }
    }

    /// The comet crosses the sky of Adrift only.
    var hasComet: Bool { self == .adrift }

    /// A small astronaut floats in the sky of Adrift only, bouncing softly off the edges of the screen as in zero gravity.
    var hasAstronaut: Bool { self == .adrift }

    /// The spaceship crosses the sky of Interstellar only, where the comet would be.
    var hasSpaceship: Bool { self == .interstellar }

    /// Interstellar is its own look: a darker night under the browse screens and the colours of a galaxy in the nebulae.
    var isInterstellar: Bool { self == .interstellar }

    var label: String {
        switch self {
        case .off: String(localized: "Off")
        case .serene: String(localized: "Serene")
        case .adrift: String(localized: "Adrift")
        case .interstellar: String(localized: "Interstellar")
        }
    }
}
