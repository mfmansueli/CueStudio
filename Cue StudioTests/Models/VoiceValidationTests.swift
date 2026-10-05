//
//  VoiceValidationTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

@Suite("My Cue Voice validation (04 · F9)")
struct VoiceTextValidatorTests {
    private let endings = ["Save this", "Follow for more", "Comment your answer", "Link in bio"]

    @Test func twoToFortyCharactersAreAccepted() {
        #expect(VoiceTextValidator.check("Hi") == .accepted("Hi"))
        #expect(VoiceTextValidator.check("  Hey fam  ") == .accepted("Hey fam"))
        #expect(VoiceTextValidator.check("a") == .tooShort)
        #expect(VoiceTextValidator.check("") == .tooShort)
        #expect(VoiceTextValidator.check(String(repeating: "x", count: 41)) == .tooLong)
        #expect(VoiceTextValidator.check(String(repeating: "x", count: 40)) == .accepted(String(repeating: "x", count: 40)))
    }

    @Test func aBlockedWordIsRefusedInAnyLanguageAndAnyCase() {
        #expect(VoiceTextValidator.check("what the FUCK") == .blocked)
        #expect(VoiceTextValidator.check("que merda") == .blocked)
        #expect(VoiceTextValidator.check("putain de jour") == .blocked)
        #expect(VoiceTextValidator.check("kill yourself") == .blocked)
        #expect(VoiceTextValidator.check("scheisse") == .blocked)
    }

    @Test func harmlessWordsThatContainAStemAreNotBlocked() {
        for word in ["Hello there", "computador novo", "Scunthorpe", "reputation matters", "shell script", "class act"] {
            #expect(!VoiceTextValidator.isBlocked(word), Comment(rawValue: word))
        }
    }

    @Test func aRepeatIsDetectedIgnoringCaseAndAccents() {
        #expect(VoiceTextValidator.check("SAVE THIS", existing: endings) == .duplicate(existing: "Save this"))
        #expect(VoiceTextValidator.check("  save this ", existing: endings) == .duplicate(existing: "Save this"))
        #expect(VoiceTextValidator.check("Café", existing: ["cafe"]) == .duplicate(existing: "cafe"))
    }

    @Test func aSmallTypoOfAnOptionOffersTheOption() {
        #expect(VoiceTextValidator.check("Save thsi", vocabulary: endings) == .typo(suggestion: "Save this", original: "Save thsi"))
        #expect(VoiceTextValidator.check("Follow for mroe", vocabulary: endings) == .typo(suggestion: "Follow for more", original: "Follow for mroe"))
        // An exact option, or something that is not close to any, is accepted as typed.
        #expect(VoiceTextValidator.check("Save this", vocabulary: endings) == .accepted("Save this"))
        #expect(VoiceTextValidator.check("See you Sunday", vocabulary: endings) == .accepted("See you Sunday"))
    }

    @Test func messagesAreTheOnesTheFlowPromises() {
        #expect(VoiceTextCheck.blocked.message == "Apple Intelligence can’t use this word.")
        #expect(VoiceTextCheck.duplicate(existing: "x").message == "Already added.")
        #expect(VoiceTextCheck.typo(suggestion: "Save this", original: "x").message == "Did you mean “Save this”?")
        #expect(VoiceTextCheck.accepted("x").message == nil)
    }

    @Test func anExampleNeedsAFewSentencesAndNoBlockedWords() {
        #expect(VoiceTextValidator.checkExample("Too short.") == .tooShort)
        #expect(VoiceTextValidator.checkExample("Okay, real talk. I used to hit snooze four times. Then I tried this.") != .tooShort)
        #expect(VoiceTextValidator.checkExample("This is some fucking long caption I wrote last week for my page.") == .blocked)
    }
}

@MainActor
@Suite("My Cue Voice edits")
struct VoiceEditTests {
    private func service() -> (CreatorProfileService, TestDefaults) {
        let defaults = TestDefaults()
        return (CreatorProfileService(defaults: defaults.defaults), defaults)
    }

    @Test func anOptionIsToggledAndTheLimitSaysMax() {
        let (service, defaults) = service()
        defer { defaults.tearDown() }
        #expect(service.toggle("Bold claim", for: .openings) == .added)
        #expect(service.toggle("Question", for: .openings) == .added)
        #expect(service.toggle("POV", for: .openings) == .limit("Max 2 openings"))
        #expect(service.profile.openings == ["Bold claim", "Question"])
        #expect(service.toggle("Question", for: .openings) == .removed)
        #expect(service.profile.openings == ["Bold claim"])
    }

    @Test func freeTextIsCheckedBeforeItIsSaved() {
        let (service, defaults) = service()
        defer { defaults.tearDown() }
        #expect(service.addCustom("x", for: .phrases) == .rejected(.tooShort))
        #expect(service.addCustom("holy shit", for: .phrases) == .rejected(.blocked))
        #expect(service.profile.phrases.isEmpty)
        #expect(service.addCustom("Hey fam", for: .phrases) == .added)
        #expect(service.addCustom("hey FAM", for: .phrases) == .alreadyThere)
        #expect(service.profile.phrases == ["Hey fam"])
        #expect(service.profile.customTags == ["Hey fam"])
    }

    @Test func aTypoOfAnOptionAsksFirstAndKeepMineSavesWhatWasTyped() {
        let (service, defaults) = service()
        defer { defaults.tearDown() }
        #expect(service.addCustom("Save thsi", for: .endings) == .suggest(suggestion: "Save this", original: "Save thsi"))
        #expect(service.profile.endings.isEmpty)
        #expect(service.addCustom("Save thsi", for: .endings, keepingTyped: true) == .added)
        #expect(service.profile.endings == ["Save thsi"])
    }

    @Test func formatsAndSwearingAreSavedAndCountInTheStrength() {
        let (service, defaults) = service()
        defer { defaults.tearDown() }
        let before = service.profile.voiceStrength
        #expect(service.toggle(format: .tutorial) == .added)
        // Swearing alone doesn't fill the style: it needs energy, sentences and words too.
        service.setSwearing(.mild)
        #expect(service.profile.voiceStrength == before + 6)
        #expect(service.toggle(format: .tutorial) == .removed)
    }

    @Test func examplesAreCappedAtThreeAndRefuseBlockedWords() {
        let (service, defaults) = service()
        defer { defaults.tearDown() }
        for index in 1...3 {
            #expect(service.addExample("Okay, real talk. This is my example number \(index). Short and mine.") == .added)
        }
        #expect(service.addExample("Okay, real talk. A fourth one that does not fit at all.") == .limit("Max 3 examples"))
        #expect(service.profile.examples.count == 3)
        service.removeExample(service.profile.examples[0].id)
        #expect(service.addExample("A shit caption that I wrote on a bad day for the page.") == .rejected(.blocked))
        #expect(service.profile.examples.count == 2)
    }

    @Test func noneOfTheseRetiresTheQuestionWithoutFillingIt() {
        let (service, defaults) = service()
        defer { defaults.tearDown() }
        #expect(service.profile.nextQuestion == .endings)
        service.decline(.endings)
        #expect(service.profile.nextQuestion == .openings)
        #expect(!service.profile.isFilled(VoicePersonalityItem.endings))
        // A real answer later takes it off the declined list.
        service.toggle("Save this", for: .endings)
        #expect(!service.profile.declinedVoiceItems.contains(.endings))
    }
}
