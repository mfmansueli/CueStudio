//
//  CreatorProfileTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

@Suite("CreatorProfile")
struct CreatorProfileTests {
    @Test func v1ProfileKeepsItsDataAndTurnsToneIntoASound() throws {
        let v1 = """
        {"name":"Maya Reyes","handle":"mayamakes","niches":["wellness"],"phrases":["Hey fam"],
         "tone":"energetic","defaultPlatform":"reels","monetizationGoals":false}
        """
        let profile = try JSONDecoder().decode(CreatorProfile.self, from: Data(v1.utf8))
        #expect(profile.name == "Maya Reyes")
        #expect(profile.niches == [.wellness])
        #expect(profile.phrases == ["Hey fam"])
        #expect(profile.sounds == [.energetic])
        #expect(profile.vocabulary == .simple)
        #expect(profile.usesVoiceInAI)
        #expect(profile.defaultPlatform == .reels)
        #expect(!profile.monetizationGoals)
    }

    @Test func roundTripsTheVoice() throws {
        let profile = CreatorProfile(sounds: [.funny], vocabulary: .technical, styles: [.opinionDriven], usesVoiceInAI: false)
        let decoded = try JSONDecoder().decode(CreatorProfile.self, from: JSONEncoder().encode(profile))
        #expect(decoded == profile)
    }

    @Test func expertToneBecomesProfessional() {
        #expect(CreatorProfile.sounds(migratingFrom: .expert) == [.professional])
    }

    @Test func theVoiceCarriesEverything() {
        let profile = CreatorProfile(niches: [.tech], phrases: ["Bora"], sounds: [.funny], vocabulary: .genZ, styles: [.storytelling])
        let voice = profile.voice
        #expect(voice.sounds == [.funny])
        #expect(voice.phrases == ["Bora"])
        #expect(voice.niches == [.tech])
        #expect(voice.vocabulary == .genZ)
        #expect(voice.styles == [.storytelling])
    }
}
