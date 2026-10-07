//
//  VoiceTypedValuesTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

/// What the creator typed under "+ Something else" (the app offers the field because its list had none of it) is what only they said: it has to reach the
/// model. Every field that takes their own words, with a value nobody else would type, is found in what is sent.
@MainActor
@Suite("Typed values reach the model")
struct VoiceTypedValuesTests {
    private static func typed() -> CreatorProfile {
        var profile = CreatorProfile()
        profile.customRole = "Chef turned coach"
        profile.credential = "ten years in restaurant kitchens"
        profile.audienceNote = "night-shift nurses"
        profile.customTopics = ["Sourdough"]
        profile.topicDetails = ["Sourdough": ["starter care"]]
        profile.openings = ["Whisper a secret"]
        profile.endings = ["See you Sunday"]
        profile.phrases = ["Stay hungry"]
        profile.customTags = ["Night owl", "Reaction videos"]
        profile.avoid = ["Cliches about mornings"]
        profile.examples = [VoiceExample(text: "Okay, real talk: bread is patience you can eat, and your starter is not dead, it is sleeping.")]
        profile.style.energy = .calm
        profile.sounds = [.warmCalm]
        profile.confirmedVoiceSteps = [.tone, .audience]
        return profile
    }

    private func sent(idea: String?) -> String {
        let voice = Self.typed().voice(inLanguage: "en", idea: idea)
        return VoiceBriefBuilder.brief(for: voice).text
    }

    @Test(arguments: [
        "Chef turned coach", "ten years in restaurant kitchens", "night-shift nurses", "Whisper a secret", "See you Sunday", "Stay hungry",
        "Night owl", "Reaction videos", "Cliches about mornings", "your starter is not dead",
    ])
    func eachTypedValueIsInWhatIsSent(value: String) {
        #expect(sent(idea: "why my sourdough starter care routine matters").contains(value), "“\(value)” never reaches the model")
        #expect(sent(idea: "why my cat sleeps on the keyboard").contains(value), "“\(value)” is lost when the idea is about something else")
    }

    @Test func theTopicTheyTypedIsSentWhenTheIdeaIsAboutItAndItsSubtopicsWhenNamed() {
        #expect(sent(idea: "my sourdough routine").contains("Topics: Sourdough."))
        #expect(sent(idea: "my sourdough starter care").contains("Sourdough (starter care)"))
        #expect(!sent(idea: "why my cat sleeps on the keyboard").contains("Sourdough"), "the idea is about something else: the subject is the idea's")
    }

    @Test func aCatchphraseTheyTypedIsNotLostBeyondTheThreeUsed() {
        var profile = Self.typed()
        profile.phrases = ["One", "Two", "Three", "Four", "Five"]
        let text = VoiceBriefBuilder.brief(for: profile.voice).text
        #expect(text.contains("“One”, “Two”, “Three”") && !text.contains("“Four”"), "three are told, so that none is said in every video")
    }
}
