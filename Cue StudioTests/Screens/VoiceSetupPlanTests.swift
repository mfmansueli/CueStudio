//
//  VoiceSetupPlanTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

/// The short setup behind "Write in my voice": it asks only what is missing, says when a step can be left, and the answers are written as they are given
/// (through the same service the editor uses), so the voice turns on at the end and never before.
@MainActor
@Suite("Voice setup plan")
struct VoiceSetupPlanTests {
    @Test func aNewProfileIsAskedAllFourQuestionsWithNothingAnswered() {
        let profile = CreatorProfile()
        let plan = VoiceSetupPlan(profile: profile)
        #expect(plan.steps == [.role, .niche, .audience, .tone])
        // The default tone and vocabulary are not answers.
        #expect(!plan.canFinish(in: profile))
        #expect(!VoiceSetupPlan.canContinue(.niche, in: profile) && !VoiceSetupPlan.canContinue(.audience, in: profile))
        #expect(!VoiceSetupPlan.canContinue(.tone, in: profile))
    }

    @Test func anOlderProfilesValuesCanBeConfirmedAsTheyAre() {
        let profile = CreatorProfile(
            niches: [.tech], sounds: [.funny, .energetic], vocabulary: .technical, unverifiedVoiceSteps: [.audience, .tone]
        )
        let plan = VoiceSetupPlan(profile: profile)
        #expect(plan.steps == [.audience, .tone])
        #expect(plan.confirmsExistingValues)
        // Nothing to pick again: it can be confirmed right away.
        #expect(plan.canFinish(in: profile))
    }

    @Test func aNewProfileConfirmsNothing() {
        #expect(!VoiceSetupPlan(profile: CreatorProfile()).confirmsExistingValues)
        #expect(!VoiceSetupPlan(profile: CreatorProfile(niches: [.tech], confirmedVoiceSteps: [.audience])).confirmsExistingValues)
    }

    @Test func anOlderProfileStillNeedsTheTopicItNeverHad() {
        var profile = CreatorProfile(sounds: [.funny], vocabulary: .technical, unverifiedVoiceSteps: [.audience, .tone])
        let plan = VoiceSetupPlan(profile: profile)
        #expect(plan.steps == [.role, .niche, .audience, .tone])
        #expect(!plan.canFinish(in: profile))
        profile.niches = [.tech]
        #expect(plan.canFinish(in: profile))
    }

    @Test func onlyWhatIsMissingIsAskedAndWhatWasAnsweredIsKept() {
        var profile = CreatorProfile(niches: [.tech], confirmedVoiceSteps: [.audience])
        let plan = VoiceSetupPlan(profile: profile)
        #expect(plan.steps == [.tone])
        #expect(!plan.canFinish(in: profile))
        profile.sounds = [.casual]
        profile.confirm(.tone)
        #expect(plan.canFinish(in: profile))
    }

    @Test func editingAsksEverythingWithTheCurrentAnswersInPlace() {
        let profile = CreatorProfile(
            niches: [.tech, .food], sounds: [.funny], vocabulary: .technical, confirmedVoiceSteps: [.audience, .tone]
        )
        let plan = VoiceSetupPlan(profile: profile, steps: VoiceSetupStep.allCases)
        #expect(plan.steps == VoiceSetupStep.allCases)
        #expect(plan.canFinish(in: profile))
    }

    @Test func aTopicOfAnyKindAndAnAudienceInTheCreatorsWordsAreAnswers() {
        var profile = CreatorProfile(confirmedVoiceSteps: [.audience, .tone], voiceTopics: [.pets])
        #expect(VoiceSetupPlan.canContinue(.niche, in: profile))
        profile = CreatorProfile(customTopics: ["Chess"])
        #expect(VoiceSetupPlan.canContinue(.niche, in: profile))
        #expect(!VoiceSetupPlan.canContinue(.audience, in: profile))
    }

    @Test func theKindOfCreatorIsNeverRequiredToFinish() {
        let profile = CreatorProfile(niches: [.tech], confirmedVoiceSteps: [.audience, .tone])
        let plan = VoiceSetupPlan(profile: profile, steps: [.role, .niche])
        #expect(plan.canFinish(in: profile))
        #expect(!VoiceSetupPlan.canContinue(.role, in: profile), "the step itself waits for an answer, the question has its own Skip")
    }

    @Test func answeringThroughTheServiceIsWhatTheSetupDoesAndTheVoiceTurnsOnAtTheEnd() {
        let store = TestDefaults()
        defer { store.tearDown() }
        let service = CreatorProfileService(defaults: store.defaults)
        service.setWritesInMyVoice(false)
        let plan = VoiceSetupPlan(profile: service.profile)
        service.toggleTopic(.niche(.finance))
        service.setAudienceGroup(.professionals)
        service.answer(.tone, with: VoiceOption(id: VoiceSound.educational.rawValue, label: "Educational"))
        #expect(plan.canFinish(in: service.profile))
        #expect(service.profile.niches == [.finance] && service.profile.vocabulary == .professional && service.profile.sounds == [.educational])
        service.setWritesInMyVoice(true)
        #expect(service.writesInMyVoice)
    }

    @Test func audienceChoicesAreTheGroupsInTheOrderThatSuitsTheKindOfCreator() {
        #expect(Vocabulary.allCases.map(\.audienceLabel) == [
            "Everyday people", "People who know the field", "A young crowd", "Professionals",
        ])
    }
}
