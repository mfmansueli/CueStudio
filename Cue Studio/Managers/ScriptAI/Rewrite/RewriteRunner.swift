//
//  RewriteRunner.swift
//  Cue Studio
//

import Foundation

/// Edits a script with a tool a part at a time and holds every part to what the tool promises (`RewriteOutcome`): a part that misses is asked again, once,
/// with what it got wrong; a part that misses twice is left as it was written, never replaced by a cut or a made-up version. The model is asked through
/// `ask`, so that this is the whole of the logic and a test can stand in for the model.
nonisolated enum RewriteRunner {
    /// One request: the text of a part, and what the model is told about it. Returns the model's answer, cleaned of markdown and quotes.
    typealias Ask = @MainActor @Sendable (_ text: String, _ part: ScriptPromptBuilder.RewritePart) async throws -> String

    static func run(_ text: String, tool: ScriptTool, context: RewriteContext, ask: Ask) async throws -> RewriteResult {
        let first = try await pass(text, tool: tool, context: context, ask: ask)
        // "Fit to time" counts words badly, part by part: a script that came back outside the length (as the length bar tells it, not within a slack
        // the bar doesn't have) gets up to two more rounds over what is left, as long as each comes nearer. Measured on the iPhone (run `after`,
        // 01/11/2026), Private Cloud Compute lengthening a script of 50 to 77 words stopped at 59 to 70 s of 75–105 after two.
        guard let goal = fitGoal(for: tool, context: context), !first.isUntouched else { return first }
        var current = first
        for _ in 0..<2 {
            let words = ReadTime.wordCount(in: current.text)
            guard !goal.contains(words) else { break }
            let next = try await pass(current.text, tool: tool, context: context, ask: ask)
            guard !next.isUntouched, distance(of: ReadTime.wordCount(in: next.text), from: goal) < distance(of: words, from: goal) else { break }
            current = RewriteResult(text: next.text, parts: first.parts, leftAsWritten: first.leftAsWritten)
        }
        return current
    }

    /// How many words `words` is outside `goal` (0 inside it).
    private static func distance(of words: Int, from goal: ClosedRange<Int>) -> Int {
        max(goal.lowerBound - words, words - goal.upperBound, 0)
    }

    private static func pass(_ text: String, tool: ScriptTool, context: RewriteContext, ask: Ask) async throws -> RewriteResult {
        let words = ReadTime.wordCount(in: text)
        let goal = fitGoal(for: tool, context: context)
        if let goal, goal.contains(words) {
            // "Fit to time" on a script that already fits has nothing to do, and no reason to ask the model to move it.
            return RewriteResult(text: text, parts: 1, leftAsWritten: 1)
        }
        let expansion = goal.map { Double(($0.lowerBound + $0.upperBound) / 2) / Double(max(1, words)) } ?? 1
        let aim = goal.map { self.aim(within: $0, from: words) }
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
                index: asking, count: asked, target: aim.map { target(for: chunk, of: words, goal: $0) }, leadIn: chunk.leadIn
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
        return RewriteResult(text: left == asked ? text : RewriteChunker.joined(outputs, gaps: chunks.map(\.gap)), parts: asked, leftAsWritten: left)
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
            // The model is told to add nothing of its own and still does: scene directions and sound effects in brackets. And it drops the
            // creator's cues, which go back where they were (`CueRestorer`). A translation renames the cues it was given, so they are kept as they
            // come; but a part with none gets none ("[Voiceover]", "[Cut to: …]" in Ultra AI's scripts).
            let translatesCues = tool == .translate && CueParser.count(in: chunk.text) > 0
            let answer = translatesCues ? raw
                : CueRestorer.restoring(RewriteOutcome.withoutInventedCues(raw, comparedTo: chunk.text), from: chunk.text)
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
        let low = ReadTime.words(for: context.idealRange.lowerBound, language: context.paceLanguage)
        let high = max(low, ReadTime.words(for: context.idealRange.upperBound, language: context.paceLanguage))
        return low...high
    }

    /// The words "Fit to time" asks for: inside the platform's range, on the side away from where the model misses. Measured on the iPhone
    /// (ScriptToolsQualityDeviceTests, 01/11/2026), cutting an Ultra AI script to 75–105 s it stopped past the top (111–132 s on the device, 106–120 s
    /// on Private Cloud Compute), and it writes less than asked when it lengthens (`lengthAskFactor`): a cut aims at the lower part of the range, a
    /// lengthening at the upper part, so a miss still lands inside it.
    private static func aim(within goal: ClosedRange<Int>, from words: Int) -> ClosedRange<Int> {
        let span = Double(goal.upperBound - goal.lowerBound)
        let (low, high) = words > goal.upperBound ? (0.05, 0.55) : (0.45, 0.95)
        return (goal.lowerBound + Int(span * low))...(goal.lowerBound + Int(span * high))
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
        case .emptyResponse, .declined, .tooLong: return true
        default: return false
        }
    }
}
