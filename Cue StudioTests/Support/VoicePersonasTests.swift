//
//  VoicePersonasTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

/// The made-up creators the measurements run on are what they say they are.
@MainActor
@Suite("Voice personas")
struct VoicePersonasTests {
    @Test func theTwelvePersonasAreDistinctAndEveryOneCanWriteInTheirVoice() {
        let personas = VoicePersonas.all
        #expect(personas.count == 12)
        #expect(Set(personas.map(\.id)).count == 12)
        for persona in personas + VoicePersonas.languageVariants {
            #expect(persona.ideas.count == 3, "\(persona.id): three ideas")
            #expect(persona.profile.hasMinimumVoice, "\(persona.id): the minimum voice is answered")
            #expect(!persona.forbiddenTerms.isEmpty && !persona.topicTerms.isEmpty, "\(persona.id): the expectations are written")
        }
    }

    @Test func eachIdeaIsReadInThePersonasLanguage() {
        for persona in VoicePersonas.all + VoicePersonas.languageVariants {
            for idea in persona.ideas {
                #expect(persona.request(for: idea).language == persona.language, "\(persona.id): “\(idea)”")
            }
        }
    }

    /// Measured before v2 (finding 4): a creator whose topics are all typed ("+ Your own") had none of the list, so nothing of their voice was
    /// sent. A typed topic, or one only My Cue Voice offers, is an answer now.
    @Test func aTypedTopicOrAVoiceOnlyTopicIsAnAnswer() throws {
        var persona = try #require(VoicePersonas.persona("yoga-teacher"))
        persona.profile.niches = []
        persona.profile.customTopics = ["Yoga for desk workers"]
        #expect(persona.profile.hasMinimumVoice)
        #expect(persona.request(for: persona.ideas[0]).voice != nil)
        persona.profile.customTopics = []
        persona.profile.voiceTopics = [.pets]
        #expect(persona.profile.hasMinimumVoice)
        persona.profile.voiceTopics = []
        #expect(!persona.profile.hasMinimumVoice, "with no topic at all the voice still isn't set")
    }

    @Test func withTheVoiceOffNothingOfTheCreatorIsSent() throws {
        let persona = try #require(VoicePersonas.persona("yoga-teacher"))
        #expect(persona.request(for: persona.ideas[0], withVoice: false).voice == nil)
    }
}
