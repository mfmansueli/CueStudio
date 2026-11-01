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

    /// Private Cloud Compute answers with the whole script and the addition in it: the addition is taken out, and a script changed here and
    /// there gives nothing.
    @Test func whenTheModelWritesTheScriptAgainOnlyTheNewRunIsTaken() {
        let script = "Morning walks changed my week. [pause] I go before coffee, every single day.\n\nTry it tomorrow and tell me."
        let answer = "Morning walks changed my week. I go before coffee — every single day.\n\nYesterday the street was empty and I heard the birds. "
            + "It felt like the day had not started yet.\n\nTry it tomorrow and tell me."
        #expect(FitTopUp.accepted(answer, into: script, asked: 20) == "Yesterday the street was empty and I heard the birds. It felt like the day had not started yet.")
        let changed = "My morning walks changed everything this week. I go before coffee, every single day.\n\nYesterday the street was empty. "
            + "\n\nTry it tomorrow and tell me."
        #expect(FitTopUp.accepted(changed, into: script, asked: 20) == nil)
    }
}
