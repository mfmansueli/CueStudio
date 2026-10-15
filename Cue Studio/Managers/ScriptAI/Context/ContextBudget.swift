//
//  ContextBudget.swift
//  Cue Studio
//

import Foundation

/// The model's window shared out (Apple: "every session interaction … consumes input and output tokens from this window", 4096 on the device): the
/// instructions, the prompt and the structure of the answer, the answer itself (`maximumResponseTokens`), and a margin. A request whose estimate is
/// well inside it goes as it is, with nothing counted; one near the edge is counted by the model's own tokenizer, and what can go goes first (the
/// voice's examples, then where and how long they post, then their tags: `VoiceBriefBuilder`), never the language, the idea, its angle, the facts
/// given or the voice's rules. Pure: the counting is passed in.
nonisolated struct ContextBudget: Sendable {
    /// Tokens kept free for what the framework adds around a request.
    static let margin = 120
    /// An estimate under this share of the window goes without an exact count.
    static let estimateShare = 0.75
    /// The voice budgets tried, in turn, for a request that doesn't fit (`VoiceBrief.budget` units): each cuts more of what is optional.
    static let voiceSteps = [1400, 900, 500, 0]

    let window: Int

    /// The tokens a request may have for its answer to have `answer`.
    func room(forAnswer answer: Int) -> Int {
        window - Self.margin - answer
    }

    /// Whether an estimate is far enough inside the window not to be counted.
    func isClearlyInside(estimate: Int, answer: Int) -> Bool {
        Double(estimate + answer + Self.margin) <= Double(window) * Self.estimateShare
    }

    /// The request that fits, the full one first: `measure` gives the tokens of a candidate (nil when it can't be counted, which ends the search with
    /// the candidate as it is). The smallest is returned when none fits: the framework then says it is too long.
    static func fitting<Candidate>(
        _ candidates: [Candidate], answer: Int, window: Int, measure: (Candidate) async -> Int?
    ) async -> (candidate: Candidate, tokens: Int?)? {
        let budget = ContextBudget(window: window)
        var last: (Candidate, Int?)?
        for candidate in candidates {
            let tokens = await measure(candidate)
            last = (candidate, tokens)
            guard let tokens else { return last }
            if tokens <= budget.room(forAnswer: answer) { return last }
        }
        return last
    }
}
