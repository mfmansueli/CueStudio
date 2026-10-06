//
//  SkyDensity.swift
//  Cue Studio
//

import Foundation

/// Which starry sky the browse screens have (Personalize › Starry sky): Off, Calm, Lively or Galactic. Calm is the default (the owner's call,
/// 6/10/2026; the creator changes it in Settings). Lively has everything: the drifting stars, the nebulae, the small twinkling stars and
/// the comet. Calm is only the drifting stars and the nebulae (nothing twinkles, no comet). Galactic is deep space: Lively's stars and
/// twinkles in the colours of a galaxy (blue, magenta and teal nebulae, a Milky Way band, a darker night), with a spaceship that crosses
/// instead of the comet. Off draws no sky at all. The raw values are the ones saved by v27 (calm, lively), so a creator's choice carries over.
nonisolated enum SkyDensity: String, CaseIterable, Identifiable, Sendable {
    case off, calm, lively, galactic

    var id: String { rawValue }

    /// The position on its four steps.
    var step: Int { Self.allCases.firstIndex(of: self) ?? 1 }

    /// How many twinkling stars a screen has: 14 at Lively and Galactic (`motion/README.md`), none at Calm.
    var twinkleCount: Int {
        switch self {
        case .off, .calm: 0
        case .lively, .galactic: 14
        }
    }

    /// The comet crosses the sky of Lively only.
    var hasComet: Bool { self == .lively }

    /// The spaceship crosses the sky of Galactic only, where the comet would be.
    var hasSpaceship: Bool { self == .galactic }

    /// Galactic is its own look: a darker night under the browse screens and the colours of a galaxy in the nebulae.
    var isGalactic: Bool { self == .galactic }

    /// "Your stars" (the small yellow one for each idea sent, above Scripts) belong to the sky: with Off no screen draws any star.
    /// They are kept, so they are back when the sky is.
    var showsYourStars: Bool { self != .off }

    var label: String {
        switch self {
        case .off: String(localized: "Off")
        case .calm: String(localized: "Calm")
        case .lively: String(localized: "Lively")
        case .galactic: String(localized: "Galactic")
        }
    }
}
