//
//  VoiceStrengthLevel.swift
//  Cue Studio
//

import Foundation

/// The words next to the voice meter: how far along My Cue Voice is.
nonisolated enum VoiceStrengthLevel: Sendable {
    case justStarted, gettingThere, goodStart, soundsLikeYou

    init(strength: Int) {
        switch strength {
        case ..<30: self = .justStarted
        case 30..<60: self = .gettingThere
        case 60..<85: self = .goodStart
        default: self = .soundsLikeYou
        }
    }

    var label: String {
        switch self {
        case .justStarted: String(localized: "Just started")
        case .gettingThere: String(localized: "Getting there")
        case .goodStart: String(localized: "Good start")
        case .soundsLikeYou: String(localized: "Sounds like you")
        }
    }
}

nonisolated extension CreatorProfile {
    var voiceLevel: VoiceStrengthLevel { VoiceStrengthLevel(strength: voiceStrength) }

    /// The voice in one line, from what the creator answered: "Entertainer · Food, Travel · Casual, Confident · For beginners".
    var voiceSentence: String {
        var parts: [String] = []
        if let role { parts.append(role.label) }
        if hasAnswered(.niche) { parts.append(niches.map(\.label).joined(separator: ", ")) }
        if isChosen(.tone) { parts.append(sounds.map(\.label).joined(separator: ", ")) }
        if isChosen(.audience) { parts.append(vocabulary.audienceLabel) }
        return parts.joined(separator: " · ")
    }
}
