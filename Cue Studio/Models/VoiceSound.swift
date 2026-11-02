//
//  VoiceSound.swift
//  Cue Studio
//

import Foundation

/// "How I sound" in My Cue Voice. A creator can pick several.
nonisolated enum VoiceSound: String, Codable, CaseIterable, Identifiable, Sendable {
    // The order the questions show them (09 §5). `casual` is "Conversational", `professional` "Straight to the point" and `funny`
    // "Playful": the raw values stay, so nothing saved needs migrating.
    case casual, professional, educational, confident, warmCalm, energetic, funny, dry

    var id: String { rawValue }

    var label: String {
        switch self {
        case .casual: String(localized: "Conversational")
        case .professional: String(localized: "Straight to the point")
        case .educational: String(localized: "Educational")
        case .confident: String(localized: "Confident")
        case .warmCalm: String(localized: "Warm & calm")
        case .energetic: String(localized: "Energetic")
        case .funny: String(localized: "Playful")
        case .dry: String(localized: "Dry & sarcastic")
        }
    }

    /// The words the AI reads in its instructions (English, whatever the interface language says): the label the creator picked, as it
    /// reads in English, never an older name ("professional" for "Straight to the point" asked for a register they didn't choose; §11, A14).
    var promptWord: String {
        switch self {
        case .casual: "conversational"
        case .professional: "straight to the point"
        case .educational: "educational"
        case .confident: "confident"
        case .warmCalm: "warm and calm"
        case .energetic: "energetic"
        case .funny: "playful"
        case .dry: "dry and sarcastic"
        }
    }

    /// A line that sounds like it, under the choice ("My oven and I are not friends.").
    var example: String {
        switch self {
        case .casual: String(localized: "“So here’s the thing…”")
        case .professional: String(localized: "“Three steps. No fluff.”")
        case .educational: String(localized: "“Let’s break down why.”")
        case .confident: String(localized: "“This is the method I trust.”")
        case .warmCalm: String(localized: "“Let’s slow down for a second.”")
        case .energetic: String(localized: "“Okay, quick one today…”")
        case .funny: String(localized: "“My alarm and I are not friends.”")
        case .dry: String(localized: "“Great. Another life hack.”")
        }
    }
}
