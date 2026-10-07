//
//  VoiceSetupPlan.swift
//  Cue Studio
//

import Foundation

/// Which of the four guided questions are asked, and when each can be left behind. The answers themselves are written as they are given, by the same
/// fields the editor uses (`CreatorProfileService`): this only decides the path. Only what the profile still lacks is asked, or all four to go over
/// them again.
struct VoiceSetupPlan: Equatable {
    let steps: [VoiceSetupStep]
    /// An asked step is showing values an older build saved (maybe choices, maybe defaults): the setup asks the creator to confirm them, with nothing
    /// to pick again.
    let confirmsExistingValues: Bool

    /// - Parameter steps: what to ask; nil asks what the profile still lacks.
    init(profile: CreatorProfile, steps: [VoiceSetupStep]? = nil) {
        // A creator setting the voice up from scratch is also asked what kind of creator they are.
        let missing = profile.missingVoiceSteps
        self.steps = steps ?? (missing.contains(.niche) && !profile.hasAnswered(.role) ? [.role] + missing : missing)
        confirmsExistingValues = self.steps.contains { !profile.hasAnswered($0) && profile.isChosen($0) }
    }

    /// Whether the answer to `step` allows going on. The kind of creator can be skipped (the question has its own "Skip"); the rest need one.
    static func canContinue(_ step: VoiceSetupStep, in profile: CreatorProfile) -> Bool {
        switch step {
        case .role: profile.hasAnswered(.role)
        case .niche: profile.topicCount > 0
        case .audience: profile.isChosen(.audience)
        case .tone: profile.isChosen(.tone) && !profile.sounds.isEmpty
        }
    }

    /// Every asked step has an answer.
    func canFinish(in profile: CreatorProfile) -> Bool {
        steps.allSatisfy { $0 == .role || Self.canContinue($0, in: profile) }
    }
}
