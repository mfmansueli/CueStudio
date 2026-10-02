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
        VoiceSetupStep.allCases.filter { !hasAnswered($0) }
    }

    /// Enough of the creator is known for the AI to write like them. With less, the voice is not applied.
    var hasMinimumVoice: Bool { missingVoiceSteps.isEmpty }
}
