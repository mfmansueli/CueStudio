//
//  VoiceLearningTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

/// "What Cue learned" (the owner's item 11, 02/11/2026): what "Adjust" keeps is listed, and taking it away puts back what it changed, without
/// undoing what the creator changed since.
@MainActor
struct VoiceLearningTests {
    private func service(_ profile: CreatorProfile) -> (CreatorProfileService, TestDefaults) {
        let defaults = TestDefaults()
        let service = CreatorProfileService(defaults: defaults.defaults)
        service.profile = profile
        return (service, defaults)
    }

    private var talker: CreatorProfile {
        var profile = CreatorProfile()
        profile.role = .educator
        profile.sounds = [.professional]
        profile.style.energy = .high
        profile.style.sentences = .mixed
        // A new profile starts with the legacy short-sentences style; this one never had it.
        profile.styles = [.conversational]
        return profile
    }

    @Test func aKeptAdjustmentIsListedAndTakenBack() throws {
        let (service, defaults) = service(talker)
        defer { defaults.tearDown() }
        service.keepAdjustments([.tooFormal])
        #expect(service.profile.sounds == [.casual])
        let learning = try #require(service.profile.learned.first)
        #expect(service.profile.learned.count == 1)
        #expect(learning.change == VoiceAdjustment.tooFormal.change)
        service.forget(learning)
        #expect(service.profile.sounds == [.professional])
        #expect(service.profile.learned.isEmpty)
    }

    @Test func takingOneBackLeavesTheOthersAndTheCreatorsOwnChanges() throws {
        let (service, defaults) = service(talker)
        defer { defaults.tearDown() }
        service.keepAdjustments([.tooOverTheTop])
        service.keepAdjustments([.tooLong], cause: .sentences)
        #expect(service.profile.style.energy == .calm && service.profile.style.sentences == .short)
        let calmer = try #require(service.profile.learned.first)
        service.forget(calmer)
        #expect(service.profile.style.energy == .high, "its own change goes back")
        #expect(service.profile.style.sentences == .short, "the other one stays")
        // The creator picks long sentences by hand: taking "Too long" back doesn't undo their choice.
        service.profile.style.sentences = .long
        service.forget(try #require(service.profile.learned.first))
        #expect(service.profile.style.sentences == .long)
        #expect(!service.profile.styles.contains(.shortSentences), "the legacy style it added goes too")
    }

    @Test func anAdjustmentThatChangesNothingIsNotListed() {
        var profile = talker
        profile.phrases = []
        let (service, defaults) = service(profile)
        defer { defaults.tearDown() }
        service.keepAdjustments([.notMyPhrase])
        #expect(service.profile.learned.isEmpty)
    }

    @Test func theListIsKeptAndBounded() throws {
        let (service, defaults) = service(talker)
        defer { defaults.tearDown() }
        for _ in 0..<(VoiceLearning.limit + 3) {
            service.profile.sounds = [.professional]
            service.keepAdjustments([.tooFormal])
        }
        #expect(service.profile.learned.count == VoiceLearning.limit)
        let decoded = try JSONDecoder().decode(CreatorProfile.self, from: JSONEncoder().encode(service.profile))
        #expect(decoded.learned == service.profile.learned)
    }
}
