//
//  VoiceQuestion.swift
//  Cue Studio
//

import Foundation

/// The weights of `voiceStrength` (08 §1, total 100): what My Cue Voice counts as filled.
nonisolated enum VoiceField: String, CaseIterable, Identifiable, Sendable {
    case role, topics, audience, tone
    case style, formats, openings, endings, phrases, avoid, reach
    case examples

    var id: String { rawValue }

    var weight: Int {
        switch self {
        case .role, .topics, .audience, .tone: 10
        case .style, .formats, .openings, .endings, .phrases: 6
        case .avoid, .reach: 5
        case .examples: 20
        }
    }

    var layer: VoiceLayer {
        switch self {
        case .role, .topics, .audience, .tone: .essentials
        case .examples: .proof
        default: .personality
        }
    }
}

nonisolated enum VoiceLayer: String, CaseIterable, Sendable {
    case essentials, personality, proof
}

/// One answer on a question: what it is called and what it is for (a line that sounds like it, the creator types it).
nonisolated struct VoiceOption: Identifiable, Hashable, Sendable {
    let id: String
    let label: String
    var detail: String?
}

/// The question bank of My Cue Voice (08 §2), in queue order: the Essentials (E1–E4), Personality (P1–P12) and Proof (X1). The tip
/// asks them one at a time, the full page (9.3) opens any of them.
nonisolated enum VoiceQuestion: String, CaseIterable, Identifiable, Sendable {
    case role, topics, audience, tone
    case endings, openings, formats, length, humor, platforms, energy, sentences, words, swearing, phrases, avoid
    case example

    var id: String { rawValue }

    /// "vq.role" and friends: the key of the question in `strings-en.csv`.
    var key: String { "vq.\(rawValue)" }

    var field: VoiceField {
        switch self {
        case .role: .role
        case .topics: .topics
        case .audience: .audience
        case .tone: .tone
        case .endings: .endings
        case .openings: .openings
        case .formats: .formats
        case .length, .humor, .platforms: .reach
        case .energy, .sentences, .words, .swearing: .style
        case .phrases: .phrases
        case .avoid: .avoid
        case .example: .examples
        }
    }

    var layer: VoiceLayer { field.layer }

    var title: String {
        switch self {
        case .role: String(localized: "What kind of creator are you?")
        case .topics: String(localized: "What do you talk about?")
        case .audience: String(localized: "Who’s watching?")
        case .tone: String(localized: "How do you talk on camera?")
        case .endings: String(localized: "How do you usually end a video?")
        case .openings: String(localized: "How do you like to open?")
        case .formats: String(localized: "What do you film most?")
        case .length: String(localized: "How long are your videos, usually?")
        case .humor: String(localized: "How much humor in your videos?")
        case .platforms: String(localized: "Where do you post most?")
        case .energy: String(localized: "What’s your energy on camera?")
        case .sentences: String(localized: "Short sentences or longer ones?")
        case .words: String(localized: "How technical are your words?")
        case .swearing: String(localized: "Any swearing?")
        case .phrases: String(localized: "A phrase you always say?")
        case .avoid: String(localized: "Anything Cue should never write?")
        case .example: String(localized: "Paste something you wrote or said")
        }
    }

    /// How an answer is given.
    enum Kind: Hashable, Sendable {
        /// One tap is the answer.
        case single
        /// Several can be picked (up to the limit); the sheet has a Save button.
        case multiple(limit: Int)
        /// The creator types first (the keyboard opens), with examples to tap below.
        case freeTextFirst
        /// Opens the Add example sheet.
        case example
    }

    var kind: Kind {
        switch self {
        case .topics: .multiple(limit: VoiceLimits.topics)
        case .tone: .multiple(limit: VoiceLimits.tones)
        case .formats: .multiple(limit: VoiceLimits.formats)
        case .avoid: .multiple(limit: VoiceLimits.avoid)
        case .phrases: .freeTextFirst
        case .example: .example
        default: .single
        }
    }

    /// "+ Something else": text the creator types (2–40 characters, 04 §F9). The closed lists (length, humor, platforms, style)
    /// have none.
    var allowsSomethingElse: Bool {
        switch self {
        case .length, .humor, .platforms, .energy, .sentences, .words, .swearing, .example: false
        default: true
        }
    }

    /// "None of these": the question is skipped for good (it can still be answered in 9.3). Swearing has none.
    var allowsNone: Bool {
        switch self {
        case .swearing, .example: false
        default: true
        }
    }

    /// The answers in the order shown, without "+ Something else" and "None of these".
    var options: [VoiceOption] {
        switch self {
        case .role: CreatorRole.allCases.map { VoiceOption(id: $0.rawValue, label: $0.label, detail: $0.examples) }
        case .topics: Niche.allCases.map { VoiceOption(id: $0.rawValue, label: $0.chipLabel) }
        case .audience: Vocabulary.allCases.map { VoiceOption(id: $0.rawValue, label: $0.audienceLabel) }
        case .tone: VoiceSound.allCases.map { VoiceOption(id: $0.rawValue, label: $0.label, detail: $0.example) }
        case .endings: VoicePersonalityItem.endings.options.map { VoiceOption(id: $0, label: $0) }
        case .openings: VoicePersonalityItem.openings.options.map { VoiceOption(id: $0, label: $0) }
        case .formats: Self.formatOptions
        case .length: VideoLength.allCases.map { VoiceOption(id: $0.rawValue, label: $0.label) }
        case .humor: HumorLevel.allCases.map { VoiceOption(id: $0.rawValue, label: $0.label) }
        case .platforms: Platform.allCases.map { VoiceOption(id: $0.rawValue, label: $0.label) }
        case .energy: VoiceEnergy.allCases.map { VoiceOption(id: $0.rawValue, label: $0.label) }
        case .sentences: SentenceLength.allCases.map { VoiceOption(id: $0.rawValue, label: $0.label) }
        case .words: WordLevel.allCases.map { VoiceOption(id: $0.rawValue, label: $0.label) }
        case .swearing: Swearing.allCases.map { VoiceOption(id: $0.rawValue, label: $0.label) }
        case .phrases:
            [String(localized: "Okay, real talk."), String(localized: "Here’s the thing."), String(localized: "Let’s go.")]
                .map { VoiceOption(id: $0, label: $0) }
        case .avoid: Self.avoidOptions
        case .example: []
        }
    }

    /// "Nothing to avoid": an answer of its own that counts as filled.
    static let nothingToAvoidID = "nothing"

    /// What the creator films most. "Talking head" has no `ScriptType` (it is kept as a tag) and "Reaction" is the Hot take / reply format.
    static let talkingHeadID = "talkingHead"
    private static var formatOptions: [VoiceOption] {
        [
            VoiceOption(id: talkingHeadID, label: String(localized: "Talking head")),
            VoiceOption(id: ScriptType.tutorial.rawValue, label: String(localized: "Tutorial / how-to")),
            VoiceOption(id: ScriptType.story.rawValue, label: String(localized: "Storytime")),
            VoiceOption(id: ScriptType.list.rawValue, label: String(localized: "List / tips")),
            VoiceOption(id: ScriptType.review.rawValue, label: String(localized: "Review")),
            VoiceOption(id: ScriptType.opinion.rawValue, label: String(localized: "Reaction")),
        ]
    }

    private static var avoidOptions: [VoiceOption] {
        [
            VoiceOption(id: "Clickbait", label: String(localized: "Clickbait")),
            VoiceOption(id: "Hype words", label: String(localized: "Hype words")),
            VoiceOption(id: "Emojis in captions", label: String(localized: "Emojis in captions")),
            VoiceOption(id: "Medical claims", label: String(localized: "Medical claims")),
            VoiceOption(id: "Politics", label: String(localized: "Politics")),
            VoiceOption(id: nothingToAvoidID, label: String(localized: "Nothing to avoid")),
        ]
    }
}
