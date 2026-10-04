//
//  VoicePersonalityItem.swift
//  Cue Studio
//

import Foundation

/// The "Personality" layer of My Cue Voice, in the order Cue asks about it one question at a time (the nudges on
/// Scripts and Takes): how they end a video, how they open, what they film, how they swear, their catchphrases.
nonisolated enum VoicePersonalityItem: String, Codable, CaseIterable, Identifiable, Sendable {
    case endings, openings, formats, swearing, phrases

    var id: String { rawValue }

    var question: String {
        switch self {
        case .endings: String(localized: "How do you usually end a video?")
        case .openings: String(localized: "How do you like to open?")
        case .formats: String(localized: "What do you film most?")
        case .swearing: String(localized: "Do you swear on camera?")
        case .phrases: String(localized: "Any phrase you always say?")
        }
    }
}
