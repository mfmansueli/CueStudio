//
//  PostCaptionTests.swift
//  Cue StudioTests
//

import Testing
@testable import Cue_Studio

/// The caption copied for a post: the hook, the title, #ad.
struct PostCaptionTests {
    @Test func theHookLeadsThenTheTitleAndAd() {
        let text = "I wasted three years filming the wrong way, and it cost me every brand deal. Here's what changed.\n\nFirst, the light."
        let caption = PostCaption.text(scriptText: text, title: "From idea to video", isSponsored: true)
        #expect(caption == "I wasted three years filming the wrong way, and it cost me every brand deal.\n\nFrom idea to video #ad")
    }

    @Test func aShortFirstSentenceTakesTheNextOne() {
        #expect(PostCaption.hook(of: "Stop. Your coffee is doing this wrong.\n\nMore.") == "Stop. Your coffee is doing this wrong.")
    }

    @Test func cuesAreNotPartOfTheHook() {
        let hook = PostCaption.hook(of: "[PAUSE] Three ways to cook rice without a rice cooker.")
        #expect(hook?.contains("PAUSE") == false)
        #expect(hook?.hasPrefix("Three ways") == true)
    }

    @Test func aHookThatSaysTheTitleDoesNotRepeatIt() {
        let caption = PostCaption.text(scriptText: "3 morning habits that changed my life, and why.", title: "3 morning habits", isSponsored: false)
        #expect(caption == "3 morning habits that changed my life, and why.")
    }

    @Test func aLongHookIsCutAtAWord() throws {
        let long = Array(repeating: "word", count: 60).joined(separator: " ") + "."
        let hook = try #require(PostCaption.hook(of: long))
        #expect(hook.hasSuffix("…") && hook.count <= PostCaption.hookLimit + 1)
    }

    @Test func noScriptIsOnlyTheTitleOrNothing() {
        #expect(PostCaption.text(scriptText: nil, title: "Unboxing", isSponsored: false) == "Unboxing")
        #expect(PostCaption.text(scriptText: "", title: "", isSponsored: true) == "#ad")
    }
}
