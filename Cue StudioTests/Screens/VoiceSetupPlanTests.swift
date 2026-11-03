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
        #expect(plan.steps == [.role, .speech, .niche, .audience, .tone])
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
        // What kind of creator they are is still unknown: it comes first (the owner, 03/11/2026); the theme, with nothing more specific, is
        // asked again for its subtopics.
        #expect(plan.steps == [.role, .speech, .niche, .audience, .tone])
        #expect(plan.asksSubtopics)
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
        #expect(plan.steps == [.role, .speech, .niche, .audience, .tone])
        #expect(!plan.asksSubtopics, "no theme yet: the step asks for themes")
        #expect(!plan.canFinish(in: profile))
        profile.niches = [.tech]
        #expect(plan.canFinish(in: profile))
    }

    @Test func onlyWhatIsMissingIsAskedAndWhatWasAnsweredIsKept() {
        var profile = CreatorProfile(niches: [.tech], confirmedVoiceSteps: [.audience], creatorKind: "developer")
        profile.topicDetails[VoiceTopicRef.niche(.tech).id] = ["Apps"]
        let plan = VoiceSetupPlan(profile: profile)
        #expect(plan.steps == [.speech, .tone])
        #expect(!plan.canFinish(in: profile))
        profile.sounds = [.casual]
        profile.confirm(.tone)
        #expect(plan.canFinish(in: profile))
    }

    @Test func afterTheFirstFlightTheKindOfCreatorComesFirstAndTheSubtopicsWithTheThemes() {
        // The first flight asked the themes only: the kind of creator first, then the themes again for what inside them.
        #expect(VoiceSetupPlan(profile: CreatorProfile(niches: [.travel])).steps == [.role, .speech, .niche, .audience, .tone])
        // Only one of the eight broad roles (an older build): the kind is asked again.
        #expect(VoiceSetupPlan(profile: CreatorProfile(niches: [.travel], role: .expert)).steps == [.role, .speech, .niche, .audience, .tone])
        #expect(VoiceSetupPlan(profile: CreatorProfile(niches: [.travel], creatorKind: "lawyer")).steps == [.speech, .niche, .audience, .tone])
        #expect(VoiceSetupPlan(profile: CreatorProfile(niches: [.travel], customRole: "Chess coach")).steps == [.speech, .niche, .audience, .tone])
        // One subtopic anywhere is enough: the themes aren't asked again.
        var profile = CreatorProfile(niches: [.travel, .food], creatorKind: "lawyer")
        profile.topicDetails[VoiceTopicRef.niche(.food).id] = ["Street food"]
        #expect(VoiceSetupPlan(profile: profile).steps == [.speech, .audience, .tone])
    }

    @Test func aVoiceInUseStillAsksWhatTheFiveStepsLackFromWhereTheCreatorStopped() {
        var profile = CreatorProfile(niches: [.tech], sounds: [.casual], confirmedVoiceSteps: [.audience, .tone])
        #expect(profile.missingVoiceSteps.isEmpty && !profile.answeredEverySetupStep)
        #expect(VoiceSetupPlan(profile: profile).steps == [.role, .speech, .niche])
        profile.creatorKind = "developer"
        profile.confirm(.speech)
        profile.topicDetails[VoiceTopicRef.niche(.tech).id] = ["Apps"]
        #expect(profile.answeredEverySetupStep && profile.pendingSetupSteps.isEmpty)
        #expect(VoiceSetupPlan(profile: profile).steps.isEmpty, "all five answered: ✦ Voice opens My Cue Voice instead")
    }

    @Test func goingOnPastHowScriptsTalkAboutThemAnswersIt() {
        var profile = CreatorProfile()
        #expect(!profile.hasAnswered(.speech))
        profile.confirm(.speech)
        #expect(profile.hasAnswered(.speech))
        #expect(CreatorProfile(speaksAs: .we).hasAnswered(.speech))
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
        var profile = CreatorProfile(niches: [.pets], confirmedVoiceSteps: [.audience, .tone])
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
