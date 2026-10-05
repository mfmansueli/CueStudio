//
//  SkyDensity.swift
//  Cue Studio
//

import Foundation

/// How alive the starry sky of the browse screens is (Personalize › Starry sky): Off, Soft or Full. Full is the default
/// (v29); Soft has half the twinkles; Off draws no sky at all. The raw values are the ones saved by
/// v27 (calm, lively), so a creator's choice carries over.
nonisolated enum SkyDensity: String, CaseIterable, Identifiable, Sendable {
    case off, calm, lively

    var id: String { rawValue }

    /// The slider's position on its three steps.
    var step: Int { Self.allCases.firstIndex(of: self) ?? 2 }

    /// How many twinkles a screen has: 14 at Full, half at Soft (`motion/README.md`).
    var twinkleCount: Int {
        switch self {
        case .off: 0
        case .calm: 7
        case .lively: 14
        }
    }

    /// The comet crosses the sky of Soft and Full.
    var hasComet: Bool { self != .off }

    var label: String {
        switch self {
        case .off: String(localized: "Off")
        case .calm: String(localized: "Soft")
        case .lively: String(localized: "Full")
        }
    }
}
