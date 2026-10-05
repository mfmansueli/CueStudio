//
//  CreatorProfile+VoiceSetup.swift
//  Cue Studio
//

import Foundation

nonisolated extension CreatorProfile {
    /// Which steps of the voice the creator has answered themselves. A new profile already holds a
    /// tone and a vocabulary (the defaults in `init`), and those are not proof that anyone set them,
    /// so audience and tone count only once chosen in the setup or in Profile. Niches start empty,
    /// so having one is the answer.
    func hasAnswered(_ step: VoiceSetupStep) -> Bool {
        switch step {
        case .role: role != nil
        case .niche: !niches.isEmpty
        case .audience, .tone: confirmedVoiceSteps.contains(step)
        }
    }

    /// Whether the value held for `step` can be shown as the creator's: answered, or saved by an older
    /// build that can't tell a choice from a default (it is kept, and confirmed before first use).
    /// A new profile's defaults are neither.
    func isChosen(_ step: VoiceSetupStep) -> Bool {
        hasAnswered(step) || unverifiedVoiceSteps.contains(step)
    }

    /// The creator answered `step`, by choosing or confirming.
    mutating func confirm(_ step: VoiceSetupStep) {
        confirmedVoiceSteps.insert(step)
        unverifiedVoiceSteps.remove(step)
    }

    /// What "Write in my voice" still needs, in the order it is asked.
    var missingVoiceSteps: [VoiceSetupStep] {
        VoiceSetupStep.allCases.filter { $0.isRequired && !hasAnswered($0) }
    }

    /// Enough of the creator is known for the AI to write like them. With less, the voice is not applied.
    var hasMinimumVoice: Bool { missingVoiceSteps.isEmpty }

    // MARK: - Strength (v30 · 08 §1)

    /// How much of the creator Cue knows, 0–100: the weights of `VoiceField` for every field filled — Essentials 40 (kind of creator,
    /// topics, audience with its level, tone), Personality 40 (style, formats, openings, endings, phrases, what to avoid, reach) and
    /// Proof 20 (one example 8, two 14, three 20; every two "Sounds like me" count as one example). Computed, so it follows
    /// every change to the profile.
    var voiceStrength: Int {
        min(100, VoiceField.allCases.reduce(0) { $0 + points(for: $1) })
    }

    /// What `field` is worth right now.
    func points(for field: VoiceField) -> Int {
        if field == .examples {
            switch provenExamples {
            case 0: return 0
            case 1: return 8
            case 2: return 14
            default: return 20
            }
        }
        return isFilled(field) ? field.weight : 0
    }

    /// Examples that prove the voice: the ones pasted, plus one for every two approvals (at most three).
    var provenExamples: Int { min(VoiceExample.limit, examples.count + approvals / 2) }

    /// Whether the creator has given Cue everything `field` asks for.
    func isFilled(_ field: VoiceField) -> Bool {
        switch field {
        case .role: role != nil
        case .topics: !niches.isEmpty || !customTopics.isEmpty
        case .audience: isChosen(.audience) && audienceLevel != nil
        case .tone: isChosen(.tone) && (1...VoiceLimits.tones).contains(sounds.count)
        case .style: style.isComplete
        case .formats: !formats.isEmpty || customTags.contains(where: { VoiceTextValidator.key($0) == VoiceTextValidator.key(Self.talkingHeadTag) })
        case .openings: !openings.isEmpty
        case .endings: !endings.isEmpty
        case .phrases: !phrases.isEmpty
        case .avoid: !avoid.isEmpty || avoidNone
        case .reach: reach.isComplete
        case .examples: provenExamples > 0
        }
    }

    /// The tag "Talking head" is kept under: it has no `ScriptType` of its own.
    static let talkingHeadTag = "Talking head"

    /// Whether this one question has been answered (a field with several questions, like style and reach, is filled by all of them).
    func isAnswered(_ question: VoiceQuestion) -> Bool {
        switch question {
        case .energy: style.energy != nil
        case .sentences: style.sentences != nil
        case .words: style.words != nil
        case .swearing: style.swearing != nil
        case .length: reach.length != nil
        case .humor: reach.humor != nil
        case .platforms: !reach.platforms.isEmpty
        case .example: examples.count >= VoiceExample.limit
        default: isFilled(question.field)
        }
    }

    /// Whether the creator has given Cue this Personality item.
    func isFilled(_ item: VoicePersonalityItem) -> Bool {
        switch item {
        case .endings: !endings.isEmpty
        case .openings: !openings.isEmpty
        case .formats: !formats.isEmpty
        case .swearing: style.swearing != nil
        case .phrases: !phrases.isEmpty
        }
    }

    /// The next question to ask: the first Personality item still empty, skipping the ones put off ("Not now").
    func nextQuestion(excluding snoozed: Set<VoicePersonalityItem> = []) -> VoicePersonalityItem? {
        VoicePersonalityItem.allCases.first { !isFilled($0) && !snoozed.contains($0) && !declinedVoiceItems.contains($0) }
    }

    var nextQuestion: VoicePersonalityItem? { nextQuestion() }
}
