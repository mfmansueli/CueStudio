//
//  SkyDensity.swift
//  Cue Studio
//

import Foundation

/// How alive the starry sky of the browse screens is (Personalize › Starry sky): Off, Soft or Full. Full is the default
/// (v29); Soft has half the twinkles and shooting stars; Off draws no sky at all. The raw values are the ones saved by
/// v27 (calm, lively), so a creator's choice carries over.
nonisolated enum SkyDensity: String, CaseIterable, Identifiable, Sendable {
    case off, calm, lively

    var id: String { rawValue }

    /// The slider's position on its three steps.
    var step: Int { Self.allCases.firstIndex(of: self) ?? 2 }

    /// How many twinkles a screen has, 3 to 8 (6 to 16 shooting-star chances are the same factor).
    var twinkleCount: Int {
        switch self {
        case .off: 0
        case .calm: 5
        case .lively: 8
        }
    }

    /// Shooting stars on a screen at once: at most two, staggered.
    var shootingStarSlots: Int {
        switch self {
        case .off: 0
        case .calm: 1
        case .lively: 2
        }
    }

    var label: String {
        switch self {
        case .off: String(localized: "Off")
        case .calm: String(localized: "Soft")
        case .lively: String(localized: "Full")
        }
    }
}
