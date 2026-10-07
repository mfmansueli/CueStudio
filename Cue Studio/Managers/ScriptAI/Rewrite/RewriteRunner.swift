//
//  RewriteRunner.swift
//  Cue Studio
//

import Foundation

/// What a tool made of a script.
nonisolated struct RewriteResult: Equatable, Sendable {
    /// The script as it is now.
    var text: String
    /// How many parts the script was edited in.
    var parts: Int
    /// Parts left as the creator wrote them: the model refused them or couldn't do what the tool says, and a part is never swapped for something worse.
    var leftAsWritten: Int

    /// Nothing the creator wrote was touched.
    var isUntouched: Bool { leftAsWritten >= parts }
}

/// Edits a script with a tool a part at a time and holds every part to what the tool promises (`RewriteOutcome`): a part that misses is asked again, once,
/// with what it got wrong; a part that misses twice is left as it was written, never replaced by a cut or a made-up version. The model is asked through
/// `ask`, so that this is the whole of the logic and a test can stand in for the model.
nonisolated enum RewriteRunner {
    /// One request: the text of a part, and what the model is told about it. Returns the model's answer, cleaned of markdown and quotes.
    typealias Ask = @MainActor @Sendable (_ text: String, _ part: ScriptPromptBuilder.RewritePart) async throws -> String

    static func run(_ text: String, tool: ScriptTool, context: RewriteContext, ask: Ask) async throws -> RewriteResult {
        let first = try await pass(text, tool: tool, context: context, ask: ask)
        // "Fit to time" counts words badly, part by part: a script that came back outside the length gets one more round over what is left.
        guard let goal = fitGoal(for: tool, context: context), !first.isUntouched else { return first }
        let widened = (Int(Double(goal.lowerBound) * (1 - RewriteOutcome.slack))...Int(Double(goal.upperBound) * (1 + RewriteOutcome.slack)))
        guard !widened.contains(ReadTime.wordCount(in: first.text)) else { return first }
        let second = try await pass(first.text, tool: tool, context: context, ask: ask)
        return second.isUntouched ? first : RewriteResult(text: second.text, parts: first.parts, leftAsWritten: first.leftAsWritten)
    }

    private static func pass(_ text: String, tool: ScriptTool, context: RewriteContext, ask: Ask) async throws -> RewriteResult {
        let words = ReadTime.wordCount(in: text)
        let goal = fitGoal(for: tool, context: context)
        if let goal, goal.contains(words) {
            // "Fit to time" on a script that already fits has nothing to do, and no reason to ask the model to move it.
            return RewriteResult(text: text, parts: 1, leftAsWritten: 1)
        }
        let expansion = goal.map { Double(($0.lowerBound + $0.upperBound) / 2) / Double(max(1, words)) } ?? 1
        let chunks = RewriteChunker.chunks(of: text, for: tool, expansion: expansion)
        let asked = chunks.filter(\.isRewritten).count
        guard asked > 0 else { return RewriteResult(text: text, parts: 1, leftAsWritten: 1) }
        var outputs: [String] = []
        var asking = 0
        var left = 0
        var skipped: (any Error)?
        for chunk in chunks {
            try Task.checkCancellation()
            guard chunk.isRewritten else {
                outputs.append(chunk.text)
                continue
            }
            asking += 1
            let part = ScriptPromptBuilder.RewritePart(
                index: asking, count: asked, target: goal.map { target(for: chunk, of: words, goal: $0) }, leadIn: chunk.leadIn
            )
            do {
                if let written = try await settle(chunk, tool: tool, part: part, ask: ask) {
                    outputs.append(written)
                } else {
                    outputs.append(chunk.text)
                    left += 1
                }
            } catch let error where asked > 1 && isSkippable(error) {
                // One part the model won't touch doesn't take the others with it.
                outputs.append(chunk.text)
                left += 1
                skipped = error
            }
        }
        if left == asked, let skipped { throw skipped }
        return RewriteResult(text: left == asked ? text : RewriteChunker.joined(outputs), parts: asked, leftAsWritten: left)
    }

    // MARK: - One part

    /// The part as the tool made it, or nil when it couldn't keep its promise in two tries.
    private static func settle(_ chunk: RewriteChunk, tool: ScriptTool, part: ScriptPromptBuilder.RewritePart, ask: Ask) async throws -> String? {
        let sourceWords = chunk.words
        let allowed = RewriteOutcome.allowedWords(for: tool, sourceWords: sourceWords, target: part.target)
        var current = part
        var best: (text: String, outcome: RewriteOutcome)?
        for _ in 0..<2 {
            let raw = try await ask(chunk.text, current)
            // The model is told to add nothing of its own and still does: scene directions and sound effects in brackets.
            let answer = tool == .translate ? raw : RewriteOutcome.withoutInventedCues(raw, comparedTo: chunk.text)
            let outcome = RewriteOutcome.judge(tool, before: chunk.text, after: answer, target: part.target)
            if outcome.isAcceptable(for: tool) { return answer }
            if best == nil || isCloser(answer, than: best?.text ?? "", allowed: allowed) { best = (answer, outcome) }
            guard let allowed else { break }
            current.correction = outcome.correction(for: tool, sourceWords: sourceWords, allowed: allowed)
        }
        guard let best, best.outcome != .unchanged, isStillUseful(best.text, tool: tool, sourceWords: sourceWords, part: part) else { return nil }
        return best.text
    }

    /// A miss that still does some of what was asked: shorter when it should be shorter, nearer the length when it should fit. Anything else (a script
    /// that lost its points, the same words back) is not worth more than what the creator wrote.
    private static func isStillUseful(_ text: String, tool: ScriptTool, sourceWords: Int, part: ScriptPromptBuilder.RewritePart) -> Bool {
        let words = ReadTime.wordCount(in: text)
        switch tool {
        case .shorterAndDirect:
            return words < sourceWords && words * 5 >= sourceWords
        case .fitToTime:
            guard let target = part.target else { return false }
            let middle = (target.lowerBound + target.upperBound) / 2
            return abs(words - middle) < abs(sourceWords - middle)
        case .inMyVoice:
            // A concise voice says the same in fewer words (measured: a founder's voice took 132 words to 57–67); losing more than that is a script gone.
            return words * 5 >= sourceWords * 2
        default:
            return false
        }
    }

    private static func isCloser(_ candidate: String, than other: String, allowed: ClosedRange<Int>?) -> Bool {
        guard let allowed else { return false }
        let middle = (allowed.lowerBound + allowed.upperBound) / 2
        return abs(ReadTime.wordCount(in: candidate) - middle) < abs(ReadTime.wordCount(in: other) - middle)
    }

    // MARK: - Length

    /// The words "Fit to time" aims for, in all; nil for the other tools.
    private static func fitGoal(for tool: ScriptTool, context: RewriteContext) -> ClosedRange<Int>? {
        guard tool == .fitToTime else { return nil }
        let low = ReadTime.words(for: context.idealRange.lowerBound)
        let high = max(low, ReadTime.words(for: context.idealRange.upperBound))
        return low...high
    }

    /// A part's share of the words the whole is to have.
    private static func target(for chunk: RewriteChunk, of total: Int, goal: ClosedRange<Int>) -> ClosedRange<Int> {
        let share = Double(chunk.words) / Double(max(1, total))
        let low = max(1, Int((Double(goal.lowerBound) * share).rounded()))
        let high = max(low, Int((Double(goal.upperBound) * share).rounded()))
        return low...high
    }

    /// What the model may refuse of one part without the rest being lost.
    private static func isSkippable(_ error: any Error) -> Bool {
        guard let error = error as? ScriptAIError else { return false }
        switch error {
        case .emptyResponse, .declined: return true
        default: return false
        }
    }
}
