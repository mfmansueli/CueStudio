//
//  CreatorVoice.swift
//  Cue Studio
//

import Foundation

/// How the creator talks, as the AI needs it: one profile for every platform. Built from
/// `CreatorProfile` and sent in the model's instructions when "Write in my voice" is on.
nonisolated struct CreatorVoice: Hashable, Sendable {
    var sounds: [VoiceSound]
    var phrases: [String]
    /// Nil when the creator hasn't picked one.
    var vocabulary: Vocabulary?
    var styles: [VoiceStyle]
    var niches: [Niche]

    /// "Casual · Confident · “Hey fam”", the one-line summary under "Write in my voice".
    var summary: String {
        let sound = sounds.prefix(2).map(\.label)
        let phrase = phrases.first.map { ["“\($0)”"] } ?? []
        return (sound + phrase).joined(separator: " · ")
    }

    /// A line in the creator's voice for the "Sounds like you" preview. Deterministic, so the
    /// preview changes only when the voice does.
    var sampleLine: String {
        let opening: String = switch sounds.first {
        case .energetic: String(localized: "Okay, this is huge!")
        case .professional: String(localized: "Here's what most people miss.")
        case .funny: String(localized: "I did something ridiculous so you don't have to.")
        case .educational: String(localized: "Let me explain this in 30 seconds.")
        case .confident: String(localized: "I'll say it: you don't need more gear.")
        case .casual, nil: String(localized: "So, real quick.")
        }
        let body: String = if styles.contains(.storytelling) {
            String(localized: "Last week I filmed five videos in one afternoon.")
        } else if styles.contains(.opinionDriven) {
            String(localized: "Most creators overthink the camera and underthink the first line.")
        } else {
            String(localized: "Your first line matters more than your camera.")
        }
        let ending: String = switch vocabulary {
        case .genZ?: " " + String(localized: "No cap.")
        case .technical?: " " + String(localized: "The hook sets retention for the whole video.")
        case .professional?: " " + String(localized: "That is what drives retention.")
        case .simple?, nil: ""
        }
        let greeting = phrases.first.map { "\($0)! " } ?? ""
        return greeting + opening + " " + body + ending
    }
}
