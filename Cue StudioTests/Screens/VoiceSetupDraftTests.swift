//
//  VoiceSetupDraftTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

/// The short setup behind "Write in my voice": it asks only what is missing, limits the choices,
/// and saves through the profile.
@MainActor
@Suite("Voice setup")
struct VoiceSetupDraftTests {
    @Test func aNewProfileIsAskedAllThreeQuestionsWithNothingPicked() {
        let draft = VoiceSetupDraft(profile: CreatorProfile())
        #expect(draft.steps == [.niche, .audience, .tone])
        // The default tone and vocabulary are not shown as if they were chosen.
        #expect(draft.niches.isEmpty && draft.vocabulary == nil && draft.sounds.isEmpty)
        #expect(!draft.canSave)
    }

    @Test func onlyWhatIsMissingIsAskedAndWhatWasAnsweredIsKept() {
        let profile = CreatorProfile(niches: [.tech], confirmedVoiceSteps: [.audience])
        let draft = VoiceSetupDraft(profile: profile)
        #expect(draft.steps == [.tone])
        #expect(!draft.canSave)
        var picked = draft
        picked.toggle(VoiceSound.casual)
        #expect(picked.canSave)
    }

    @Test func editingAsksEverythingWithTheCurrentAnswersPicked() {
        let profile = CreatorProfile(
            niches: [.tech, .food], sounds: [.funny], vocabulary: .technical, confirmedVoiceSteps: [.audience, .tone]
        )
        let draft = VoiceSetupDraft(profile: profile, steps: VoiceSetupStep.allCases)
        #expect(draft.niches == [.tech, .food] && draft.vocabulary == .technical && draft.sounds == [.funny])
        #expect(draft.canSave)
    }

    @Test func choicesAreLimitedAndAnExtraOneIsIgnored() {
        var draft = VoiceSetupDraft(profile: CreatorProfile())
        let first = draft.toggle(VoiceSound.casual)
        let second = draft.toggle(VoiceSound.funny)
        #expect(first && second)
        #expect(!draft.canAddSound)
        let third = draft.toggle(VoiceSound.energetic)
        #expect(!third)
        #expect(draft.sounds == [.casual, .funny])
        // Letting one go makes room.
        let letGo = draft.toggle(VoiceSound.casual)
        let added = draft.toggle(VoiceSound.energetic)
        #expect(letGo && added)
        #expect(draft.sounds == [.funny, .energetic])

        for niche in [Niche.tech, .food, .beauty] { draft.toggle(niche) }
        let fourth = draft.toggle(Niche.fitness)
        #expect(!fourth)
        #expect(draft.niches == [.tech, .food, .beauty])
    }

    @Test func aProfileThatAlreadyHoldsMoreThanTheLimitKeepsThemAll() {
        let profile = CreatorProfile(sounds: [.casual, .funny, .confident], confirmedVoiceSteps: [.tone])
        var draft = VoiceSetupDraft(profile: profile, steps: [.tone])
        #expect(draft.sounds.count == 3)
        // At its own count, nothing more can be added, but nothing is dropped either.
        #expect(!draft.canAddSound)
        draft.toggle(VoiceSound.confident)
        #expect(draft.sounds == [.casual, .funny] && draft.canSave)
    }

    @Test func savingNeedsEveryAskedStepAnswered() {
        var draft = VoiceSetupDraft(profile: CreatorProfile())
        draft.toggle(Niche.tech)
        #expect(!draft.canSave)
        draft.choose(.professional)
        #expect(!draft.canSave)
        draft.toggle(VoiceSound.confident)
        #expect(draft.canSave)
    }

    @Test func savingWritesThroughTheProfileAndTurnsTheVoiceOn() {
        let store = TestDefaults()
        defer { store.tearDown() }
        let service = CreatorProfileService(defaults: store.defaults)
        service.setWritesInMyVoice(false)
        var draft = VoiceSetupDraft(profile: service.profile)
        draft.toggle(Niche.finance)
        draft.choose(.technical)
        draft.toggle(VoiceSound.educational)
        draft.save(to: service)
        #expect(service.profile.niches == [.finance] && service.profile.vocabulary == .technical && service.profile.sounds == [.educational])
        #expect(service.writesInMyVoice)
    }

    @Test func aSetupThatCannotBeSavedChangesNothing() {
        let store = TestDefaults()
        defer { store.tearDown() }
        let service = CreatorProfileService(defaults: store.defaults)
        service.setWritesInMyVoice(false)
        let before = service.profile
        VoiceSetupDraft(profile: service.profile).save(to: service)
        #expect(service.profile == before)
        #expect(!service.writesInMyVoice)
    }

    @Test func audienceChoicesAreTheProfilesVocabularyWithAudienceWords() {
        #expect(Vocabulary.allCases.map(\.audienceLabel) == [
            "Everyday people", "People who know the field", "A young crowd", "Professionals",
        ])
    }
}
