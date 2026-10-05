//
//  CoreColor.swift
//  Cue Studio
//

import Foundation

/// The light at the centre of the creator's universe (v30 · 9.2, 11.3): four colours of the core "YOU". Each is a ball painted with four stops
/// (a highlight, two body tones and a deep edge) and a soft glow. The default is gold.
nonisolated enum CoreColor: String, CaseIterable, Identifiable, Sendable {
    case gold, amber, sunrise, rose

    var id: String { rawValue }

    var label: String {
        switch self {
        case .gold: String(localized: "Gold")
        case .amber: String(localized: "Amber")
        case .sunrise: String(localized: "Sunrise")
        case .rose: String(localized: "Rose")
        }
    }

    /// The ball's four stops as `0xRRGGBB`: highlight, light body, body and edge (the board's `--core-a…d`).
    var stops: (highlight: UInt32, light: UInt32, body: UInt32, edge: UInt32) {
        switch self {
        case .gold: (0xFFFBEA, 0xFFE680, 0xFFD60A, 0xB88A00)
        case .amber: (0xFFF4E0, 0xFFC46B, 0xFF9F0A, 0xA85E00)
        case .sunrise: (0xFFF0EA, 0xFFB08A, 0xFF7A45, 0xA83A12)
        case .rose: (0xFFF0F6, 0xFFB3D6, 0xFF7AB6, 0xA3346A)
        }
    }

    /// The glow around it (the board's `--core-g`): a colour and its opacity.
    var glow: (hex: UInt32, opacity: Double) {
        switch self {
        case .gold: (0xFFD60A, 0.55)
        case .amber: (0xFF9F0A, 0.5)
        case .sunrise: (0xFF7A45, 0.5)
        case .rose: (0xFF7AB6, 0.45)
        }
    }
}
