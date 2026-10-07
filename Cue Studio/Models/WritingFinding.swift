//
//  WritingFinding.swift
//  Cue Studio
//

import Foundation

/// One thing Cue found in the writing the creator imported, as the review shows it: what it found, and whether it goes into My Cue Voice. Each
/// is a switch the creator can turn off; a finding that would replace something they already answered starts off.
nonisolated struct WritingFinding: Identifiable, Hashable, Sendable {
    enum Kind: String, CaseIterable, Sendable {
        case tones, topics, audience, sentences, words, energy, humor, swearing, speaksAs, length, phrases, openings, endings
    }

    enum Value: Hashable, Sendable {
        case tones([VoiceSound])
        /// The ids of topics (`VoiceTopicRef.id`).
        case topics([String])
        case audience(AudienceGroup)
        case sentences(SentenceLength)
        case words(WordLevel)
        case energy(VoiceEnergy)
        case humor(HumorLevel)
        case swearing(Swearing)
        case speaksAs(SpeaksAs)
        case length(VideoLength)
        case phrases([String])
        /// The English ids of the catalog (`VoiceChoiceCatalog`).
        case openings([String])
        case endings([String])

        var kind: Kind {
            switch self {
            case .tones: .tones
            case .topics: .topics
            case .audience: .audience
            case .sentences: .sentences
            case .words: .words
            case .energy: .energy
            case .humor: .humor
            case .swearing: .swearing
            case .speaksAs: .speaksAs
            case .length: .length
            case .phrases: .phrases
            case .openings: .openings
            case .endings: .endings
            }
        }
    }

    /// In how many of the texts a habit was found.
    struct Support: Hashable, Sendable {
        let found: Int
        let of: Int
    }

    var value: Value
    var isOn: Bool
    /// The creator already answered this another way: turning it on replaces their answer.
    var replaces: Bool
    var support: Support?

    var id: Kind { value.kind }
}
