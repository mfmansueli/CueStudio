//
//  AudioStrength.swift
//  Cue Studio
//

import Foundation

/// How much of a sound treatment: none, a little, or more. Kept conservative on purpose: the
/// strong setting still sounds like the same voice in the same room.
nonisolated enum AudioStrength: String, LenientChoice, CaseIterable, Identifiable, Sendable {
    /// Read in place of a value a newer version of Cue added (`LenientChoice`).
    static let fallback = AudioStrength.soft

    case off, soft, strong

    var id: String { rawValue }

    var label: String {
        switch self {
        case .off: String(localized: "Off")
        case .soft: String(localized: "Light")
        case .strong: String(localized: "Strong")
        }
    }
}
