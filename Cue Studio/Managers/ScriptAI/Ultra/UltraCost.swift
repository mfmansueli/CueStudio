//
//  UltraCost.swift
//  Cue Studio
//

import Foundation

/// What some Ultra calls spent, in Google's own token counts (each answer's usage, the numbers the bill is made from), and the dollars they come
/// to at `UltraPrice`. A call that failed before Google reported its usage counts in `calls` with no tokens (`unmeteredCalls`): what it spent,
/// if anything, only the bill shows.
nonisolated struct UltraCost: Hashable, Sendable, Codable {
    /// The calls that went out, failures included.
    var calls = 0
    /// The calls whose usage Google reported.
    var meteredCalls = 0
    /// The whole prompt: instructions, request and the cached part.
    var inputTokens = 0
    /// The part of the prompt served from Google's cache, billed at the cache's price.
    var cachedTokens = 0
    /// The answer.
    var outputTokens = 0
    /// The thinking before the answer, billed as output.
    var thinkingTokens = 0

    init() {}

    var unmeteredCalls: Int { calls - meteredCalls }

    /// One call that went out, with its answer when it came back with Google's usage (nil when it failed).
    mutating func add(_ reply: UltraModelReply?) {
        calls += 1
        guard let reply, let prompt = reply.promptTokens else { return }
        meteredCalls += 1
        inputTokens += prompt
        cachedTokens += min(reply.cachedTokens ?? 0, prompt)
        outputTokens += reply.outputTokens ?? 0
        thinkingTokens += reply.thinkingTokens ?? 0
    }

    func dollars(at price: UltraPrice = .current) -> Double {
        let input = Double(inputTokens - cachedTokens) * price.inputPerMillion + Double(cachedTokens) * price.cachedInputPerMillion
        return (input + Double(outputTokens + thinkingTokens) * price.outputPerMillion) / 1_000_000
    }

    static func + (lhs: UltraCost, rhs: UltraCost) -> UltraCost {
        var sum = lhs
        sum += rhs
        return sum
    }

    static func += (lhs: inout UltraCost, rhs: UltraCost) {
        lhs.calls += rhs.calls
        lhs.meteredCalls += rhs.meteredCalls
        lhs.inputTokens += rhs.inputTokens
        lhs.cachedTokens += rhs.cachedTokens
        lhs.outputTokens += rhs.outputTokens
        lhs.thinkingTokens += rhs.thinkingTokens
    }
}
