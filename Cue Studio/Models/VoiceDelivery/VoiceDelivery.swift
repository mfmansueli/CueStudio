//
//  VoiceDelivery.swift
//  Cue Studio
//

import Foundation

/// How the creator comes across on camera (My Cue Voice · Personality, 08 §1 `style`): energy, sentences, words and swearing. It counts
/// as filled when all four are answered.
nonisolated struct VoiceDelivery: Codable, Hashable, Sendable {
    var energy: VoiceEnergy?
    var sentences: SentenceLength?
    var words: WordLevel?
    var swearing: Swearing?

    init(energy: VoiceEnergy? = nil, sentences: SentenceLength? = nil, words: WordLevel? = nil, swearing: Swearing? = nil) {
        self.energy = energy
        self.sentences = sentences
        self.words = words
        self.swearing = swearing
    }

    var isComplete: Bool { energy != nil && sentences != nil && words != nil && swearing != nil }
    var isEmpty: Bool { energy == nil && sentences == nil && words == nil && swearing == nil }

    private enum CodingKeys: String, CodingKey { case energy, sentences, words, swearing }

    /// A value a newer build added reads as unanswered, so the profile still opens.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        energy = (try? container.decodeIfPresent(VoiceEnergy.self, forKey: .energy)) ?? nil
        sentences = (try? container.decodeIfPresent(SentenceLength.self, forKey: .sentences)) ?? nil
        words = (try? container.decodeIfPresent(WordLevel.self, forKey: .words)) ?? nil
        swearing = (try? container.decodeIfPresent(Swearing.self, forKey: .swearing)) ?? nil
    }
}
