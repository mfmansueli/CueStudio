//
//  VoiceStrengthLevel.swift
//  Cue Studio
//

import Foundation

/// The words next to the voice meter: how far along My Cue Voice is. The meter counts what was filled in, not how well a script sounds like
/// the creator, so its top says so: "Profile 85% filled", and "Profile complete" only at 100% (decision 8, 30/10/2026).
nonisolated enum VoiceStrengthLevel: Equatable, Sendable {
    case justStarted, gettingThere, goodStart
    /// 85% or more, short of all of it.
    case nearlyFilled(Int)
    case complete

    init(strength: Int) {
        switch strength {
        case ..<30: self = .justStarted
        case 30..<60: self = .gettingThere
        case 60..<85: self = .goodStart
        case 85..<100: self = .nearlyFilled(strength)
        default: self = .complete
        }
    }

    var label: String {
        switch self {
        case .justStarted: String(localized: "Just started")
        case .gettingThere: String(localized: "Getting there")
        case .goodStart: String(localized: "Good start")
        case .nearlyFilled(let strength): String(localized: "Profile \(strength)% filled")
        case .complete: String(localized: "Profile complete")
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
