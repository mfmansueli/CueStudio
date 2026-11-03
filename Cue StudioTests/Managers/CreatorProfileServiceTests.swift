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

    @Test func oneIdeaPerVideoIsKeptAndAnOlderProfileReadsItAsOff() throws {
        var profile = CreatorProfile(name: "Maya")
        profile.style = VoiceDelivery(energy: .calm, sentences: .short, oneIdea: true)
        let saved = try JSONEncoder().encode(profile)
        let read = try JSONDecoder().decode(CreatorProfile.self, from: saved)
        #expect(read.style.oneIdea && read == profile)
        // Off, it isn't written: a profile saves as it did before.
        profile.style.oneIdea = false
        #expect(String(bytes: try JSONEncoder().encode(profile), encoding: .utf8)?.contains("oneIdea") == false)
        let old = #"{"name":"Maya","style":{"energy":"calm","sentences":"short"}}"#
        let older = try JSONDecoder().decode(CreatorProfile.self, from: Data(old.utf8))
        #expect(!older.style.oneIdea && older.style.energy == .calm && older.style.sentences == .short)
        // A value it can't read is off too, and the rest of the style still opens.
        let odd = #"{"name":"Maya","style":{"energy":"calm","oneIdea":"yes"}}"#
        let lenient = try JSONDecoder().decode(CreatorProfile.self, from: Data(odd.utf8))
        #expect(!lenient.style.oneIdea && lenient.style.energy == .calm)
    }

    @Test func oneIdeaPerVideoShowsInTheStyleAndTurnsOff() {
        let store = TestDefaults()
        defer { store.tearDown() }
        let service = CreatorProfileService(defaults: store.defaults)
        service.profile.style.energy = .calm
        #expect(!service.profile.value(for: .style).contains(VoiceDelivery.oneIdeaLabel))
        service.profile = VoiceAdjustment.tooLong.applied(to: service.profile, cause: .ideas)
        #expect(service.profile.value(for: .style).hasSuffix(VoiceDelivery.oneIdeaLabel))
        #expect(VoicePageRow.style.value(in: service.profile).contains(VoiceDelivery.oneIdeaLabel))
        service.setOneIdea(false)
        #expect(!service.profile.style.oneIdea && !service.profile.value(for: .style).contains(VoiceDelivery.oneIdeaLabel))
        // Kept on this iPhone like the rest of the profile.
        service.setOneIdea(true)
        #expect(CreatorProfileService(defaults: store.defaults).profile.style.oneIdea)
    }

    @Test func aProfileSavedBeforeThisSetupDecodesWithNothingConfirmed() throws {
        let old = #"{"name":"Maya","niches":["wellness"],"sounds":["funny"],"vocabulary":"technical"}"#
        let profile = try JSONDecoder().decode(CreatorProfile.self, from: Data(old.utf8))
        // Only the niche is proof; the tone and vocabulary might be defaults, so they are asked,
        // with what is saved kept and shown as the current values.
        #expect(profile.missingVoiceSteps == [.audience, .tone])
        #expect(profile.unverifiedVoiceSteps == [.audience, .tone])
        // Funny is no longer a tone (the owner's item 4): it is kept as a little humor.
        #expect(profile.sounds.isEmpty && profile.reach.humor == .little && profile.vocabulary == .technical)
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
        // Funny and energetic are no longer tones (the owner's item 4): they come back as humor and energy.
        #expect(reloaded.profile.sounds.isEmpty && reloaded.profile.reach.humor == .little && reloaded.profile.style.energy == .high)
        #expect(reloaded.profile.vocabulary == .genZ)
    }

    /// "Clear my answers" (the owner, 03/11/2026): the voice starts over, the themes and who they are on Profile stay.
    @Test func clearingTheVoiceKeepsTheThemesAndStartsTheRestOver() {
        let store = TestDefaults()
        defer { store.tearDown() }
        let service = CreatorProfileService(defaults: store.defaults)
        service.profile.name = "Maya Reyes"
        service.profile.niches = [.food, .travel]
        service.profile.customTopics = ["Chess"]
        service.profile.creatorKind = "chef"
        service.profile.phrases = ["Okay, real talk."]
        service.profile.speaksAs = .we
        service.profile.topicDetails[VoiceTopicRef.niche(.food).id] = ["Baking"]
        service.profile.examples = [VoiceExample(text: "So here’s the thing.")]
        service.profile.confirm(.audience)
        service.profile.confirm(.tone)
        service.clearVoice()
        let cleared = CreatorProfileService(defaults: store.defaults).profile
        #expect(cleared.name == "Maya Reyes" && cleared.niches == [.food, .travel] && cleared.customTopics == ["Chess"])
        #expect(cleared.creatorKind == nil && cleared.phrases.isEmpty && cleared.speaksAs == nil && cleared.examples.isEmpty)
        #expect(cleared.subtopics(of: .niche(.food)).isEmpty && cleared.confirmedVoiceSteps.isEmpty && cleared.voiceStrength < 30)
        #expect(cleared.pendingSetupSteps == [.role, .speech, .niche, .audience, .tone])
    }
}
