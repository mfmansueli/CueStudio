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

nonisolated enum VoiceEnergy: String, Codable, CaseIterable, Identifiable, Sendable {
    case calm, balanced, high

    var id: String { rawValue }

    var label: String {
        switch self {
        case .calm: String(localized: "Calm")
        case .balanced: String(localized: "Balanced")
        case .high: String(localized: "High")
        }
    }
}

nonisolated enum SentenceLength: String, Codable, CaseIterable, Identifiable, Sendable {
    case short, mixed, long

    var id: String { rawValue }

    var label: String {
        switch self {
        case .short: String(localized: "Short")
        case .mixed: String(localized: "Mixed")
        case .long: String(localized: "Long")
        }
    }
}

nonisolated enum WordLevel: String, Codable, CaseIterable, Identifiable, Sendable {
    case plain, someSlang, expertTerms

    var id: String { rawValue }

    var label: String {
        switch self {
        case .plain: String(localized: "Plain")
        case .someSlang: String(localized: "Some slang")
        case .expertTerms: String(localized: "Expert terms")
        }
    }
}

/// Where they post, how long, how funny (08 §1 `reach`); filled when all three are answered.
nonisolated struct VoiceReach: Codable, Hashable, Sendable {
    var platforms: [Platform]
    var length: VideoLength?
    var humor: HumorLevel?

    init(platforms: [Platform] = [], length: VideoLength? = nil, humor: HumorLevel? = nil) {
        self.platforms = platforms
        self.length = length
        self.humor = humor
    }

    var isComplete: Bool { !platforms.isEmpty && length != nil && humor != nil }
    var isEmpty: Bool { platforms.isEmpty && length == nil && humor == nil }

    private enum CodingKeys: String, CodingKey { case platforms, length, humor }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        platforms = (try? container.decodeIfPresent([Platform].self, forKey: .platforms)) ?? []
        length = (try? container.decodeIfPresent(VideoLength.self, forKey: .length)) ?? nil
        humor = (try? container.decodeIfPresent(HumorLevel.self, forKey: .humor)) ?? nil
    }
}

nonisolated enum VideoLength: String, Codable, CaseIterable, Identifiable, Sendable {
    case under30, thirtyToSixty, oneToThree, longer

    var id: String { rawValue }

    var label: String {
        switch self {
        case .under30: String(localized: "Under 30 s")
        case .thirtyToSixty: String(localized: "30–60 s")
        case .oneToThree: String(localized: "1–3 min")
        case .longer: String(localized: "Longer")
        }
    }
}

nonisolated enum HumorLevel: String, Codable, CaseIterable, Identifiable, Sendable {
    /// Not `none`: that name reads as an absent value (`humor: .none`).
    case noHumor = "none", little, lot

    var id: String { rawValue }

    var label: String {
        switch self {
        case .noHumor: String(localized: "None")
        case .little: String(localized: "A little")
        case .lot: String(localized: "A lot")
        }
    }
}

/// How much the creator's audience already knows (08 E3, second part).
nonisolated enum AudienceLevel: String, Codable, CaseIterable, Identifiable, Sendable {
    case new, some, experienced

    var id: String { rawValue }

    var label: String {
        switch self {
        case .new: String(localized: "New to it")
        case .some: String(localized: "Some basics")
        case .experienced: String(localized: "Experienced")
        }
    }
}
