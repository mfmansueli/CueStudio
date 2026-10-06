//
//  OnboardingTopic.swift
//  Cue Studio
//

import SwiftUI

/// What a creator talks about: one of the topics Cue knows (`Niche`, which the AI also reads) or one
/// they typed. In the story each becomes a world with its own color, in the order they were picked.
nonisolated enum OnboardingTopic: Hashable, Identifiable, Sendable {
    case niche(Niche)
    case custom(String)

    var id: String {
        switch self {
        case .niche(let niche): "niche.\(niche.rawValue)"
        case .custom(let name): "custom.\(name.lowercased())"
        }
    }

    var label: String {
        switch self {
        case .niche(let niche): niche.chipLabel
        case .custom(let name): name
        }
    }

    /// Up to three topics make a universe.
    static let limit = 3

    /// The color of the world at `index` (0 is the first picked).
    @MainActor
    static func color(at index: Int) -> Color {
        [Palette.worldWarm, Palette.worldMint, Palette.worldPink, Palette.worldSky][min(max(0, index), 3)]
    }
}
