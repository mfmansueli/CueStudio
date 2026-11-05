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

    /// An idea from Find inspiration still as it came is a suggestion: ↻ passes it. Changed, or put over the creator's own words, it is theirs.
    @Test func anUntouchedInspirationCanBePassedButAChangedOneCannot() {
        var idea = ThemeIdea(title: "Saving on groceries", kind: "Tips", length: .minute1, niche: .finance)
        idea.brief = IdeaBrief(subject: "Saving on groceries", angle: "Three swaps that cut the bill.", openingLine: "Your cart costs too much.")
        let draft = IdeaDraftService()
        draft.use(idea)
        #expect(draft.holdsUntouchedIdea)
        draft.dropIdea()
        #expect(draft.isEmpty && draft.brief == nil)

        draft.use(idea)
        draft.text += " for students"
        #expect(!draft.holdsUntouchedIdea, "changed, it is theirs")
        draft.dropIdea()
        #expect(!draft.isEmpty)

        let over = IdeaDraftService()
        over.text = "my own words"
        over.use(idea)
        #expect(!over.holdsUntouchedIdea, "their words wait behind it for Undo")
    }

    @Test func aBrandBriefReachesTheRequestOnlyForAnAd() {
        let brand = BrandBrief(name: "Oat & Co.", product: "Milk")
        let defaults = TestDefaults()
        defer { defaults.tearDown() }
        let factory = ScriptRequestFactory(
            profile: CreatorProfileService(defaults: defaults.defaults), scriptLanguage: nil,
            interfaceLanguage: .english
        )
        #expect(factory.request(idea: "x", platform: .tiktok, format: .ad, brand: brand).brand == brand)
        #expect(factory.request(idea: "x", platform: .tiktok, format: .review, brand: brand).brand == nil)
        #expect(factory.request(idea: "x", platform: .tiktok, format: nil, brand: brand).brand == nil)
    }
}
