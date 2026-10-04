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

    // MARK: - Strength (v29 · 04 F9)

    /// How much of the creator Cue knows, 0–100: Essentials 60% (kind of creator, topics, audience and tone, 15 each),
    /// Personality 25% (openings, endings, catchphrases, formats and swearing, 5 each) and Proof 15% (1–3 examples
    /// the creator wrote, 5 each). Computed, so it follows every change to the profile.
    var voiceStrength: Int {
        let essentials = VoiceSetupStep.allCases.filter { isChosen($0) }.count * 15
        let personality = VoicePersonalityItem.allCases.filter { isFilled($0) }.count * 5
        let proof = min(VoiceExample.limit, examples.count) * 5
        return essentials + personality + proof
    }

    /// Whether the creator has given Cue this Personality item.
    func isFilled(_ item: VoicePersonalityItem) -> Bool {
        switch item {
        case .endings: !endings.isEmpty
        case .openings: !openings.isEmpty
        case .formats: !formats.isEmpty
        case .swearing: swearing != nil
        case .phrases: !phrases.isEmpty
        }
    }

    /// The next question to ask: the first Personality item still empty, skipping the ones put off ("Not now").
    func nextQuestion(excluding snoozed: Set<VoicePersonalityItem> = []) -> VoicePersonalityItem? {
        VoicePersonalityItem.allCases.first { !isFilled($0) && !snoozed.contains($0) && !declinedVoiceItems.contains($0) }
    }

    var nextQuestion: VoicePersonalityItem? { nextQuestion() }
}
