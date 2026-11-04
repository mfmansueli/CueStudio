//
//  UltraCostTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

/// What Ultra's calls cost: Google's token counts at the catalog's price, thinking billed as output, the cached part of the prompt at the cache's
/// price, and a failed call counted with no tokens.
@Suite("Ultra AI cost")
struct UltraCostTests {
    private func reply(prompt: Int?, cached: Int? = nil, output: Int? = nil, thinking: Int? = nil) -> UltraModelReply {
        UltraModelReply(
            text: "", finishedNormally: true, promptTokens: prompt, cachedTokens: cached, outputTokens: output, thinkingTokens: thinking
        )
    }

    @Test func theCatalogsPriceForGemini35FlashGlobal() {
        #expect(UltraPrice.google == UltraPrice(inputPerMillion: 1.50, cachedInputPerMillion: 0.15, outputPerMillion: 9.00))
    }

    /// The server picks Claude's model, so a call is priced at the model the answer says it came from; an unknown id at Sonnet's.
    @Test func claudesPricePerModel() {
        #expect(UltraPrice.claude("claude-opus-5-5") == UltraPrice(inputPerMillion: 4, cachedInputPerMillion: 0.20, outputPerMillion: 20))
        #expect(UltraPrice.claude("claude-sonnet-5-5") == UltraPrice(inputPerMillion: 2, cachedInputPerMillion: 0.20, outputPerMillion: 10))
        #expect(UltraPrice.claude("claude-haiku-5-5") == UltraPrice(inputPerMillion: 0.10, cachedInputPerMillion: 0.01, outputPerMillion: 0.50))
        #expect(UltraPrice.claude(nil) == UltraPrice.claude("claude-sonnet-5-5"))
    }

    @Test func aMillionTokensInAndOutCostTheirPrices() {
        var cost = UltraCost()
        cost.add(reply(prompt: 1_000_000))
        #expect(abs(cost.dollars(at: .google) - 1.50) < 1e-9)
        cost = UltraCost()
        cost.add(reply(prompt: 0, output: 1_000_000))
        #expect(abs(cost.dollars(at: .google) - 9.00) < 1e-9)
    }

    /// The day's lion's share: thinking is billed as output.
    @Test func thinkingIsBilledAsOutput() {
        var cost = UltraCost()
        cost.add(reply(prompt: 0, thinking: 1_000_000))
        #expect(abs(cost.dollars(at: .google) - 9.00) < 1e-9)
    }

    @Test func theCachedPartOfThePromptCostsTheCachesPrice() {
        var cost = UltraCost()
        cost.add(reply(prompt: 1_000_000, cached: 400_000))
        #expect(abs(cost.dollars(at: .google) - (0.6 * 1.50 + 0.4 * 0.15)) < 1e-9)
        // More cached than the prompt (never from Google) is held to the prompt.
        cost = UltraCost()
        cost.add(reply(prompt: 100, cached: 500))
        #expect(cost.cachedTokens == 100)
    }

    /// The 29/10 comparison's mean three-step script, the number the report gave.
    @Test func aMeanThreeStepScriptIsAboutSevenAndAHalfCents() {
        var cost = UltraCost()
        cost.add(reply(prompt: 1_000, output: 650, thinking: 1_600))
        cost.add(reply(prompt: 1_400, output: 500, thinking: 2_500))
        cost.add(reply(prompt: 1_465, output: 489, thinking: 2_053))
        #expect(cost.calls == 3 && cost.meteredCalls == 3)
        #expect(cost.inputTokens == 3_865 && cost.outputTokens == 1_639 && cost.thinkingTokens == 6_153)
        #expect(abs(cost.dollars(at: .google) - 0.0759255) < 1e-7)
    }

    @Test func aFailedCallCountsWithNoTokens() {
        var cost = UltraCost()
        cost.add(reply(prompt: 1_000, output: 500))
        cost.add(nil)
        cost.add(reply(prompt: nil))
        #expect(cost.calls == 3 && cost.meteredCalls == 1 && cost.unmeteredCalls == 2)
        #expect(cost.inputTokens == 1_000 && cost.outputTokens == 500)
    }

    @Test func costsAddUp() {
        var one = UltraCost()
        one.add(reply(prompt: 10, cached: 2, output: 20, thinking: 30))
        var two = UltraCost()
        two.add(reply(prompt: 1, output: 2, thinking: 3))
        two.add(nil)
        let sum = one + two
        #expect(sum.calls == 3 && sum.meteredCalls == 2)
        #expect(sum.inputTokens == 11 && sum.cachedTokens == 2 && sum.outputTokens == 22 && sum.thinkingTokens == 33)
        #expect(abs(sum.dollars(at: .google) - (one.dollars(at: .google) + two.dollars(at: .google))) < 1e-12)
    }
}
