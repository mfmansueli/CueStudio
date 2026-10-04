//
//  IdeaSuggestionTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

@MainActor
@Suite("Idea card · suggestion, format and brand")
struct IdeaSuggestionTests {
    @Test func theCardSuggestsAnIdeaFromTheCreatorsTopicsAndAnotherOneRotates() {
        let draft = IdeaDraftService()
        let first = draft.suggestion(for: [.finance])
        draft.anotherSuggestion()
        let second = draft.suggestion(for: [.finance])
        #expect(first != nil && second != nil)
        #expect(first != second)
        #expect(first?.niche == .finance)
    }

    @Test func withNoTopicTheSuggestionComesFromLifestyle() {
        #expect(IdeaDraftService().suggestion(for: [])?.niche == .lifestyle)
    }

    @Test func theFormatChoiceKeepsTalkingHeadApartFromAuto() {
        let draft = IdeaDraftService()
        draft.formatChoice = .talkingHead
        #expect(draft.format == nil)
        #expect(draft.formatChoice == .talkingHead)
        draft.format = .review
        #expect(draft.formatChoice == .type(.review))
        draft.format = nil
        #expect(draft.formatChoice == .auto)
    }

    @Test func sendingTheIdeaClearsTheFormatTheBrandAndTheRest() {
        let draft = IdeaDraftService()
        draft.formatChoice = .type(.ad)
        draft.brand = BrandBrief(name: "Oat & Co.", product: "Milk")
        draft.text = "an idea"
        draft.clear()
        #expect(draft.formatChoice == .auto)
        #expect(draft.brand == nil)
        #expect(draft.isEmpty)
    }

    @Test func aBrandBriefReachesTheRequestOnlyForAnAd() {
        let brand = BrandBrief(name: "Oat & Co.", product: "Milk")
        let defaults = TestDefaults()
        defer { defaults.tearDown() }
        let factory = ScriptRequestFactory(
            rules: TestData.rulesService(), profile: CreatorProfileService(defaults: defaults.defaults), scriptLanguage: nil,
            interfaceLanguage: .english
        )
        #expect(factory.request(idea: "x", platform: .tiktok, format: .ad, brand: brand).brand == brand)
        #expect(factory.request(idea: "x", platform: .tiktok, format: .review, brand: brand).brand == nil)
        #expect(factory.request(idea: "x", platform: .tiktok, format: nil, brand: brand).brand == nil)
    }
}
