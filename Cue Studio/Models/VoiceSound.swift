//
//  VoiceSound.swift
//  Cue Studio
//

import Foundation

/// "How I sound" in My Cue Voice. A creator can pick several.
nonisolated enum VoiceSound: String, Codable, CaseIterable, Identifiable, Sendable {
    case casual, energetic, professional, funny, educational, confident

    var id: String { rawValue }

    var label: String {
        switch self {
        case .casual: String(localized: "Casual")
        case .energetic: String(localized: "Energetic")
        case .professional: String(localized: "Professional")
        case .funny: String(localized: "Funny")
        case .educational: String(localized: "Educational")
        case .confident: String(localized: "Confident")
        }
    }

    /// A line that sounds like it, under the choice ("My oven and I are not friends.").
    var example: String {
        switch self {
        case .casual: String(localized: "“So here’s the thing…”")
        case .energetic: String(localized: "“Okay, you need to hear this!”")
        case .professional: String(localized: "“Here’s what the data shows.”")
        case .funny: String(localized: "“My oven and I are not friends.”")
        case .educational: String(localized: "“Let’s break down why.”")
        case .confident: String(localized: "“This is the method I trust.”")
        }
    }

    /// The format tone this sound leans toward, used to preselect a tone in a brief.
    var tone: Tone? {
        switch self {
        case .casual: .casual
        case .energetic: .energetic
        case .funny: .funny
        case .professional, .educational: .expert
        case .confident: nil
        }
    }
}
