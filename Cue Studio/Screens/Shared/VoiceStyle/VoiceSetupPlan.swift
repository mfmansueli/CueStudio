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
    /// The themes are asked although picked (in the first flight, say), for what they talk about inside each: the step says so.
    let asksSubtopics: Bool

    /// - Parameter steps: what to ask; nil asks what the profile still lacks.
    init(profile: CreatorProfile, steps: [VoiceSetupStep]? = nil) {
        self.steps = steps ?? Self.asked(by: profile)
        confirmsExistingValues = self.steps.contains { !profile.hasAnswered($0) && profile.isChosen($0) }
        asksSubtopics = self.steps.contains(.niche) && profile.hasAnswered(.niche)
    }

    /// What the setup asks, in `VoiceSetupStep`'s order: every step still to answer, so it goes on from where the creator stopped (the owner,
    /// 03/11/2026): what kind of creator they are first whenever it is still unknown, how scripts talk about them on a screen of its own, and
    /// the themes again when none has anything more specific yet, so the subtopics are given right there (the first flight asks themes only).
    private static func asked(by profile: CreatorProfile) -> [VoiceSetupStep] {
        profile.pendingSetupSteps
    }

    /// Whether the answer to `step` allows going on. The kind of creator can be skipped (the question has its own "Skip"); the rest need one.
    static func canContinue(_ step: VoiceSetupStep, in profile: CreatorProfile) -> Bool {
        switch step {
        case .role: profile.hasAnswered(.role)
        case .speech: true
        case .niche: profile.topicCount > 0
        case .audience: profile.isChosen(.audience)
        case .tone: profile.isChosen(.tone) && !profile.sounds.isEmpty
        }
    }

    /// Every asked step has an answer.
    func canFinish(in profile: CreatorProfile) -> Bool {
        steps.allSatisfy { !$0.isRequired || Self.canContinue($0, in: profile) }
    }
}
