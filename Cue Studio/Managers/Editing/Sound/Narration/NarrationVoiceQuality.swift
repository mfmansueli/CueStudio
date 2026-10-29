//
//  NarrationVoiceQuality.swift
//  Cue Studio
//

import Foundation

/// How natural a system voice sounds (`AVSpeechSynthesisVoice.quality`): the compact voice every iPhone has, or the larger
/// Enhanced and Premium ones a creator downloads in Settings › Accessibility › Spoken Content › Voices.
nonisolated enum NarrationVoiceQuality: Int, Comparable, Sendable {
    case standard, enhanced, premium

    /// "Enhanced" or "Premium"; nil for the compact voice, which says nothing.
    var label: String? {
        switch self {
        case .standard: nil
        case .enhanced: String(localized: "Enhanced")
        case .premium: String(localized: "Premium")
        }
    }

    static func < (lhs: Self, rhs: Self) -> Bool { lhs.rawValue < rhs.rawValue }
}
