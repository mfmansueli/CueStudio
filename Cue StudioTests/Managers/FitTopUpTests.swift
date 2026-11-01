//
//  FitTopUpTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

/// What "Fit to time" adds to a lengthening that stopped short: where it goes, and what is never let in.
@Suite("Fit top-up")
struct FitTopUpTests {
    @Test func theAdditionGoesInAsAParagraphBeforeTheClosingOne() {
        let script = "Morning walks changed my week.\n\nI go before coffee.\n\nTry it tomorrow and tell me."
        let text = FitTopUp.inserting("Even ten minutes clears my head.", into: script)
        #expect(text == "Morning walks changed my week.\n\nI go before coffee.\n\nEven ten minutes clears my head.\n\nTry it tomorrow and tell me.")
    }

    @Test func inOneParagraphItGoesBeforeTheLastSentenceAndItsCue() {
        let script = "Morning walks changed my week. I go before coffee. Try it tomorrow. [smile]"
        let text = FitTopUp.inserting("Even ten minutes clears my head.", into: script)
        #expect(text == "Morning walks changed my week. I go before coffee. Even ten minutes clears my head. Try it tomorrow. [smile]")
    }

    @Test func anAdditionWithAnInventedNumberOrCueOrTheScriptAgainIsRefused() {
        let script = "Morning walks changed my week. I go before coffee, every single day. Try it tomorrow."
        #expect(FitTopUp.accepted("Studies say 73% of people feel calmer after a walk outside.", into: script, asked: 12) == nil)
        #expect(FitTopUp.accepted("I go before coffee, every single day. And it helps a lot.", into: script, asked: 12) == nil)
        #expect(FitTopUp.accepted("[Cut to park] Even a short loop clears my head [pause] before work starts.", into: script, asked: 12)
            == "Even a short loop clears my head before work starts.")
        #expect(FitTopUp.accepted("Yes.", into: script, asked: 40) == nil, "far shorter than asked")
    }
}
