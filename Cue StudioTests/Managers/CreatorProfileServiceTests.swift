//
//  CreatorProfileServiceTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

@MainActor
@Suite("CreatorProfileService")
struct CreatorProfileServiceTests {
    @Test func phrasesAreCleanedAndUnique() {
        let store = TestDefaults()
        defer { store.tearDown() }
        let service = CreatorProfileService(defaults: store.defaults)
        #expect(service.addPhrase("  “Hey fam”  "))
        #expect(!service.addPhrase("hey FAM"))
        #expect(!service.addPhrase("   "))
        #expect(service.profile.phrases == ["Hey fam"])
        service.removePhrase("Hey fam")
        #expect(service.profile.phrases.isEmpty)
    }

    @Test func nichesToggle() {
        let store = TestDefaults()
        defer { store.tearDown() }
        let service = CreatorProfileService(defaults: store.defaults)
        service.toggleNiche(.tech)
        #expect(service.profile.niches == [.tech])
        service.toggleNiche(.tech)
        #expect(service.profile.niches.isEmpty)
    }

    @Test func profilePersists() {
        let store = TestDefaults()
        defer { store.tearDown() }
        let service = CreatorProfileService(defaults: store.defaults)
        service.profile.name = "Maya Reyes"
        service.profile.defaultPlatform = .youtube
        let reloaded = CreatorProfileService(defaults: store.defaults)
        #expect(reloaded.profile.name == "Maya Reyes")
        #expect(reloaded.profile.defaultPlatform == .youtube)
        #expect(reloaded.profile.initials == "MR")
    }

    // MARK: - Write in my voice

    @Test func aNewProfileHasNoVoiceYetEvenThoughItHoldsDefaults() {
        let store = TestDefaults()
        defer { store.tearDown() }
        let service = CreatorProfileService(defaults: store.defaults)
        // Defaults exist (a tone, a vocabulary, the switch on) but are not the creator's answers.
        #expect(!service.profile.sounds.isEmpty && service.profile.usesVoiceInAI)
        #expect(service.profile.missingVoiceSteps == [.niche, .audience, .tone])
        #expect(!service.profile.hasMinimumVoice && !service.writesInMyVoice)
    }

    @Test func theSwitchWontTurnOnWithoutTheMinimumAndTurnsOffAlways() {
        let store = TestDefaults()
        defer { store.tearDown() }
        let service = CreatorProfileService(defaults: store.defaults)
        #expect(!service.setWritesInMyVoice(true))
        #expect(!service.writesInMyVoice)
        #expect(service.setWritesInMyVoice(false))
        #expect(!service.profile.usesVoiceInAI)
    }

    @Test func theSetupSavesIntoTheProfilesOwnFieldsAndTurnsTheVoiceOn() {
        let store = TestDefaults()
        defer { store.tearDown() }
        let service = CreatorProfileService(defaults: store.defaults)
        service.setWritesInMyVoice(false)
        service.saveVoiceSetup(niches: [.fitness, .food], vocabulary: .genZ, sounds: [.energetic, .funny])
        #expect(service.profile.niches == [.fitness, .food])
        #expect(service.profile.vocabulary == .genZ)
        #expect(service.profile.sounds == [.energetic, .funny])
        #expect(service.profile.missingVoiceSteps.isEmpty)
        #expect(service.writesInMyVoice)
        // It is persisted like any other Profile edit, so Profile shows it and the next launch keeps it.
        let reloaded = CreatorProfileService(defaults: store.defaults)
        #expect(reloaded.writesInMyVoice && reloaded.profile.vocabulary == .genZ)
        #expect(reloaded.profile.voice.niches == [.fitness, .food])
    }

    @Test func choosingTheDefaultVocabularyStillCountsAsAnswering() {
        let store = TestDefaults()
        defer { store.tearDown() }
        let service = CreatorProfileService(defaults: store.defaults)
        service.setVocabulary(.simple)
        #expect(!service.profile.missingVoiceSteps.contains(.audience))
        service.toggleSound(.funny)
        #expect(!service.profile.missingVoiceSteps.contains(.tone))
        service.toggleNiche(.tech)
        #expect(service.profile.hasMinimumVoice)
    }

    @Test func aSetupAnswersOnlyWhatItAskedAndLeavesTheRest() {
        let store = TestDefaults()
        defer { store.tearDown() }
        let service = CreatorProfileService(defaults: store.defaults)
        service.toggleNiche(.beauty)
        service.setVocabulary(.professional)
        service.saveVoiceSetup(sounds: [.confident])
        #expect(service.profile.niches == [.beauty] && service.profile.vocabulary == .professional)
        #expect(service.profile.sounds == [.confident])
        #expect(service.writesInMyVoice)
        // An empty answer changes nothing.
        service.saveVoiceSetup(niches: [], sounds: [])
        #expect(service.profile.niches == [.beauty] && service.profile.sounds == [.confident])
    }

    @Test func aProfileSavedBeforeThisSetupDecodesWithNothingConfirmed() throws {
        let old = #"{"name":"Maya","niches":["wellness"],"sounds":["funny"],"vocabulary":"technical"}"#
        let profile = try JSONDecoder().decode(CreatorProfile.self, from: Data(old.utf8))
        // Only the niche is proof; the tone and vocabulary might be defaults, so they are asked,
        // with what is saved kept and shown as the current values.
        #expect(profile.missingVoiceSteps == [.audience, .tone])
        #expect(profile.unverifiedVoiceSteps == [.audience, .tone])
        #expect(profile.sounds == [.funny] && profile.vocabulary == .technical)
        #expect(profile.isChosen(.audience) && profile.isChosen(.tone))
    }

    @Test func aNewProfileHasNothingToConfirm() {
        let profile = CreatorProfile()
        #expect(profile.unverifiedVoiceSteps.isEmpty)
        #expect(!profile.isChosen(.audience) && !profile.isChosen(.tone))
    }

    @Test func confirmingWhatAnOlderProfileHeldKeepsItAndIsRemembered() throws {
        let store = TestDefaults()
        defer { store.tearDown() }
        let old = #"{"name":"Maya","niches":["wellness"],"sounds":["funny","energetic"],"vocabulary":"genZ","phrases":["Hey fam"]}"#
        store.defaults.set(Data(old.utf8), forKey: DefaultsKey.creatorProfile)
        let service = CreatorProfileService(defaults: store.defaults)
        // What an older build saved can't be told from a default: the tone and the vocabulary are not used until the creator confirms them.
        #expect(service.profile.voice.sounds.isEmpty && service.profile.voice.vocabulary == nil)
        #expect(!service.profile.hasMinimumVoice)
        // Confirmed as it is, without picking anything again: the data is untouched.
        service.saveVoiceSetup(vocabulary: .genZ, sounds: [.funny, .energetic])
        #expect(service.writesInMyVoice && service.profile.voice.sounds == [.funny, .energetic])
        #expect(service.profile.phrases == ["Hey fam"] && service.profile.niches == [.wellness])
        // It is remembered: nothing is asked again after a relaunch.
        let reloaded = CreatorProfileService(defaults: store.defaults)
        #expect(reloaded.profile.unverifiedVoiceSteps.isEmpty)
        #expect(reloaded.profile.missingVoiceSteps.isEmpty && reloaded.writesInMyVoice)
        #expect(reloaded.profile.sounds == [.funny, .energetic] && reloaded.profile.vocabulary == .genZ)
    }

    @Test func theFirstToneAPersonPicksStartsFromNothingSoTheDefaultsNeverRideAlong() {
        let store = TestDefaults()
        defer { store.tearDown() }
        let service = CreatorProfileService(defaults: store.defaults)
        service.toggleSound(.funny)
        #expect(service.profile.sounds == [.funny])
        service.toggleSound(.casual)
        #expect(service.profile.sounds == [.funny, .casual])
    }

    @Test func anOlderProfilesTonesAreKeptWhenOneIsToggled() throws {
        let store = TestDefaults()
        defer { store.tearDown() }
        store.defaults.set(Data(#"{"sounds":["funny","energetic"],"vocabulary":"simple"}"#.utf8), forKey: DefaultsKey.creatorProfile)
        let service = CreatorProfileService(defaults: store.defaults)
        service.toggleSound(.confident)
        #expect(service.profile.sounds == [.funny, .energetic, .confident])
    }
}
