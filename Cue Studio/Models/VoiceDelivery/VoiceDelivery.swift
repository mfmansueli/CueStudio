//
//  VoiceDelivery.swift
//  Cue Studio
//

import Foundation

/// How the creator comes across on camera (My Cue Voice · Personality, 08 §1 `style`): energy, sentences, words and swearing. It counts
/// as filled when all four are answered. `oneIdea` is not one of the questions: "Adjust" › Too long › Too many ideas sets it, and the
/// delivery editor turns it off.
nonisolated struct VoiceDelivery: Codable, Hashable, Sendable {
    var energy: VoiceEnergy?
    var sentences: SentenceLength?
    var words: WordLevel?
    var swearing: Swearing?
    /// One idea per video, with no side points (the brief says it: `VoiceBriefBuilder`).
    var oneIdea: Bool

    init(
        energy: VoiceEnergy? = nil, sentences: SentenceLength? = nil, words: WordLevel? = nil, swearing: Swearing? = nil, oneIdea: Bool = false
    ) {
        self.energy = energy
        self.sentences = sentences
        self.words = words
        self.swearing = swearing
        self.oneIdea = oneIdea
    }

    /// `oneIdea` as the voice page and the delivery editor show it.
    static var oneIdeaLabel: String { String(localized: "One idea per video") }

    var isComplete: Bool { energy != nil && sentences != nil && words != nil && swearing != nil }
    var isEmpty: Bool { energy == nil && sentences == nil && words == nil && swearing == nil && !oneIdea }

    private enum CodingKeys: String, CodingKey { case energy, sentences, words, swearing, oneIdea }

    /// A value a newer build added reads as unanswered, so the profile still opens; a profile saved before `oneIdea` reads it as off.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        energy = (try? container.decodeIfPresent(VoiceEnergy.self, forKey: .energy)) ?? nil
        sentences = (try? container.decodeIfPresent(SentenceLength.self, forKey: .sentences)) ?? nil
        words = (try? container.decodeIfPresent(WordLevel.self, forKey: .words)) ?? nil
        swearing = (try? container.decodeIfPresent(Swearing.self, forKey: .swearing)) ?? nil
        oneIdea = (try? container.decodeIfPresent(Bool.self, forKey: .oneIdea)) ?? false
    }

    /// `oneIdea` is written only when on, so a profile without it is saved as before.
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(energy, forKey: .energy)
        try container.encodeIfPresent(sentences, forKey: .sentences)
        try container.encodeIfPresent(words, forKey: .words)
        try container.encodeIfPresent(swearing, forKey: .swearing)
        if oneIdea { try container.encode(oneIdea, forKey: .oneIdea) }
    }
}
