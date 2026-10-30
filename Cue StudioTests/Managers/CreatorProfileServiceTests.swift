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
    @Test func aPhraseIsRemoved() {
        let store = TestDefaults()
        defer { store.tearDown() }
        let service = CreatorProfileService(defaults: store.defaults)
        service.profile.phrases = ["Hey fam", "Let's go"]
        service.removePhrase("Hey fam")
        #expect(service.profile.phrases == ["Let's go"])
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
}
