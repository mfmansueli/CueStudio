//
//  VoiceTypedAnswerEventTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

/// "+ Something else" counted, never read (the owner's B14, 02/11/2026; §11): the question and whether it matched an option, nothing more.
@MainActor
struct VoiceTypedAnswerEventTests {
    private func service(_ defaults: TestDefaults) -> (CreatorProfileService, () -> [VoiceTypedAnswerEvent]) {
        let profile = CreatorProfileService(defaults: defaults.defaults)
        var events: [VoiceTypedAnswerEvent] = []
        profile.reportTypedAnswer = { events.append($0) }
        return (profile, { events })
    }

    @Test func theEventCarriesTheQuestionAndTheMatchNeverTheText() {
        let typed = VoiceTypedAnswerEvent(question: .endings, raw: "Até a próxima, família", options: VoiceQuestion.endings.options.map(\.label))
        #expect(typed.parameters == ["question": "endings", "outcome": "no_match"])
        #expect(!typed.parameters.values.contains { $0.contains("família") })
        let option = VoiceQuestion.endings.options[0].label
        #expect(VoiceTypedAnswerEvent(question: .endings, raw: option, options: [option]).matchesAnOption)
        #expect(VoiceTypedAnswerEvent(question: .endings, raw: String(option.dropLast()), options: [option]).matchesAnOption, "a typo of one")
    }

    @Test func eachTypedAnswerIsCountedOnce() {
        let defaults = TestDefaults()
        defer { defaults.tearDown() }
        let (profile, events) = service(defaults)
        profile.addSomethingElse("Até a próxima, família", for: .endings)
        #expect(events().map(\.question) == ["endings"])
        profile.addSomethingElse("Até a próxima, família", for: .endings)
        #expect(events().count == 1, "already there: not counted again")
        profile.addSomethingElse("Bora pra cima", for: .phrases, keepingTyped: true)
        #expect(events().count == 1, "\"Keep mine\" after a suggestion was counted when it was typed")
        profile.addSomethingElse("x", for: .avoid)
        #expect(events().count == 1, "rejected: not counted")
    }

    @Test func theKindOfCreatorAndTheAudienceAreCountedToo() {
        let defaults = TestDefaults()
        defer { defaults.tearDown() }
        let (profile, events) = service(defaults)
        profile.setCustomRole("Personal trainer de idosos")
        profile.setAudienceNote("Mães de primeira viagem")
        #expect(events().map(\.question) == ["role", "audience"])
        profile.setAudienceNote("")
        #expect(events().count == 2, "clearing isn't an answer")
    }
}
