//
//  VoiceQuestion.swift
//  Cue Studio
//

import Foundation

/// The question bank of My Cue Voice (08 §2): the grammar of the script language (how the words about the creator agree, how viewers are
/// addressed), the Essentials (E1–E4), Personality (P1–P12) and Proof (X1). The tip asks them one at a time in `askingOrder`, the full page
/// (9.3) opens any of them.
nonisolated enum VoiceQuestion: String, CaseIterable, Identifiable, Sendable {
    case speakerGender, groupGender, address
    case role, topics, audience, tone
    case endings, openings, formats, length, humor, platforms, energy, sentences, words, swearing, phrases, avoid
    case example

    var id: String { rawValue }

    /// The order the tip asks in: first what kind of creator they are, with what their videos are for (the owner, 03/11/2026: it tells the scripts
    /// and the ideas the most, so it is the first question); then how the words about the creator (or their team) agree and how scripts speak to
    /// viewers, asked only where the script language needs them (`VoiceQuestionScheduler`); then the audience (the owner's item 13,
    /// 02/11/2026); then the other Essentials, the Personality details and, last, the example.
    static let askingOrder: [VoiceQuestion] = [
        .role,
        .speakerGender, .groupGender, .address,
        .audience, .topics, .tone,
        .endings, .openings, .formats, .length, .humor, .platforms, .energy, .sentences, .words, .swearing, .phrases, .avoid,
        .example,
    ]

    /// Answered with one tap on the tip itself: a single answer from a closed list (no "+ Something else" to type, no second part).
    var answersInTip: Bool {
        guard case .single = kind else { return false }
        return !allowsSomethingElse
    }

    var field: VoiceField {
        switch self {
        // "Write me as" and "Speak to viewers" live under "Scripts say I / We", in the editor of who the creator is.
        case .speakerGender, .groupGender, .address: .role
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

    var title: String {
        switch self {
        case .speakerGender: String(localized: "How should scripts write you?")
        case .groupGender: String(localized: "How should scripts write your team?")
        case .address: String(localized: "How should scripts speak to viewers?")
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
        case .speakerGender, .groupGender, .address, .length, .humor, .platforms, .energy, .sentences, .words, .swearing, .example: false
        default: true
        }
    }

    /// "None of these": the question is skipped for good (it can still be answered in 9.3). Swearing and the grammar have none ("No gender"
    /// and "Informal" are answers of their own).
    var allowsNone: Bool {
        switch self {
        case .speakerGender, .groupGender, .address, .swearing, .example: false
        default: true
        }
    }

    /// The answers in the order shown, without "+ Something else" and "None of these".
    var options: [VoiceOption] {
        switch self {
        case .speakerGender, .groupGender: WordGender.allCases.map { VoiceOption(id: $0.rawValue, label: $0.label) }
        case .address: AddressForm.allCases.map { VoiceOption(id: $0.rawValue, label: $0.label) }
        case .role: CreatorKind.all.map { VoiceOption(id: $0.id, label: $0.title) }
        case .topics: Self.topicOptions
        // The editor's eight groups, one list for the tip and the page (the owner's B13, 02/11/2026; §11): a group sets its vocabulary too.
        case .audience: AudienceGroup.allCases.map { VoiceOption(id: $0.rawValue, label: $0.label) }
        // The five tones (the owner's item 4): calm, energetic and funny are said in "Your style" and "Humor".
        case .tone: VoiceSound.offered.map { VoiceOption(id: $0.rawValue, label: $0.label, detail: $0.example) }
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

    /// The broad themes, the same the first flight offers. One a creator already holds outside these (wellness) is shown by the editor next to them.
    static var topicOptions: [VoiceOption] {
        Niche.offered.map { VoiceOption(id: $0.rawValue, label: $0.chipLabel) }
    }

    /// "Nothing to avoid": an answer of its own that counts as filled.
    static let nothingToAvoidID = "nothing"

    /// What the creator films most. "Reaction" is the Hot take / reply format and "Myth vs fact" has its own; the formats that have no `ScriptType`
    /// ("Talking head", "Day in the life", "Q&A", "Behind the scenes", "Before/after") are kept as a tag in `customTags` (`formatTags`).
    static let talkingHeadID = "talkingHead"
    static let dayInTheLifeID = "dayInTheLife"
    static let questionsID = "questionsAndAnswers"
    static let behindTheScenesID = "behindTheScenes"
    static let beforeAfterID = "beforeAfter"

    /// The tag each format with no `ScriptType` is kept under (English, the way "Talking head" always was).
    static let formatTags: [String: String] = [
        talkingHeadID: CreatorProfile.talkingHeadTag,
        dayInTheLifeID: "Day in the life",
        questionsID: "Q&A",
        behindTheScenesID: "Behind the scenes",
        beforeAfterID: "Before/after",
    ]

    /// The name a format kept as a tag is shown under (the interface language's), whatever case it was kept in.
    static func formatTagLabel(_ tag: String) -> String {
        let id = formatTags.first { VoiceTextValidator.key($0.value) == VoiceTextValidator.key(tag) }?.key
        return formatOptions.first { $0.id == id }?.label ?? tag
    }

    private static var formatOptions: [VoiceOption] {
        [
            VoiceOption(id: talkingHeadID, label: String(localized: "Talking head")),
            VoiceOption(id: ScriptType.tutorial.rawValue, label: String(localized: "Tutorial / how-to")),
            VoiceOption(id: ScriptType.story.rawValue, label: String(localized: "Storytime")),
            VoiceOption(id: ScriptType.list.rawValue, label: String(localized: "List / tips")),
            VoiceOption(id: ScriptType.review.rawValue, label: String(localized: "Review")),
            VoiceOption(id: ScriptType.opinion.rawValue, label: String(localized: "Reaction")),
            VoiceOption(id: dayInTheLifeID, label: String(localized: "Day in the life")),
            VoiceOption(id: ScriptType.mythFact.rawValue, label: String(localized: "Myth vs fact")),
            VoiceOption(id: questionsID, label: String(localized: "Q&A")),
            VoiceOption(id: behindTheScenesID, label: String(localized: "Behind the scenes")),
            VoiceOption(id: beforeAfterID, label: String(localized: "Before/after")),
        ]
    }

    private static var avoidOptions: [VoiceOption] {
        [
            VoiceOption(id: "Clickbait", label: String(localized: "Clickbait")),
            VoiceOption(id: "Hype words", label: String(localized: "Hype words")),
            VoiceOption(id: "Emojis in captions", label: String(localized: "Emojis in captions")),
            VoiceOption(id: "Medical claims", label: String(localized: "Medical claims")),
            VoiceOption(id: "Politics", label: String(localized: "Politics")),
            VoiceOption(id: "Exaggerated promises", label: String(localized: "Exaggerated promises")),
            VoiceOption(id: "False urgency", label: String(localized: "False urgency")),
            VoiceOption(id: "Naming competitors", label: String(localized: "Naming competitors")),
            VoiceOption(id: VoiceAvoidRule.callsToActionID, label: String(localized: "Calls to action")),
            VoiceOption(id: nothingToAvoidID, label: String(localized: "Nothing to avoid")),
        ]
    }
}
