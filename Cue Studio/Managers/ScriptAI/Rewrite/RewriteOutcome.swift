//
//  RewriteOutcome.swift
//  Cue Studio
//

import Foundation

/// Whether what the model wrote does what the tool's name says: "Shorter" is shorter, "Fix grammar" is the same script with the mistakes fixed and not a
/// third of it, "Fit to time" lands in the platform's length, and nothing but the closing paragraph changes for "Stronger CTA". Measured on an iPhone 15 Pro,
/// the model did none of it reliably (a script cut to 188 words by "Fix grammar", "In my voice" at 45% of the length with "keep the same length" asked,
/// scene directions nobody asked for), and a tool that says "done" over the wrong words is a button that lies.
nonisolated enum RewriteOutcome: Equatable, Sendable {
    /// What was promised.
    case kept
    /// The same words came back.
    case unchanged
    /// Fewer words than the tool may leave (`wanted`: the least).
    case tooShort(words: Int, wanted: Int)
    /// More words than the tool may leave (`wanted`: the most).
    case tooLong(words: Int, wanted: Int)
    /// Stage cues of the script that were dropped (`had` of them, `kept` still there).
    case lostCues(had: Int, kept: Int)

    /// How much to widen a length the model is asked for: it counts badly, and a few words either way is not a miss.
    static let slack = 0.15

    // MARK: - Judging

    /// The number of words a result may have, for a part of `words` words. `target` is the range asked of "Fit to time" for this part.
    static func allowedWords(for tool: ScriptTool, sourceWords words: Int, target: ClosedRange<Int>? = nil) -> ClosedRange<Int>? {
        func scaled(_ low: Double, _ high: Double, extra: Int = 0) -> ClosedRange<Int> {
            max(1, Int((Double(words) * low).rounded(.down)))...max(2, Int((Double(words) * high).rounded(.up)) + extra)
        }
        switch tool {
        case .fitToTime:
            guard let target else { return nil }
            return max(1, Int((Double(target.lowerBound) * (1 - slack)).rounded(.down)))...Int((Double(target.upperBound) * (1 + slack)).rounded(.up))
        case .shorterAndDirect:
            // Cut about a third; at least a little, and not so much that the points go. A part too small to cut only mustn't grow.
            guard words >= 15 else { return 1...max(1, words) }
            return scaled(0.45, 0.9)
        case .fixGrammar: return scaled(0.85, 1.15, extra: 1)
        case .moreEnergy, .moreHuman: return scaled(0.6, 1.3, extra: 2)
        case .lessDefensive: return scaled(0.5, 1.2, extra: 1)
        case .inMyVoice: return scaled(0.5, 1.4, extra: 2)
        case .strongerCTA: return max(3, words / 2)...(words * 2 + 8)
        case .translate: return scaled(0.5, 2.0, extra: 3)
        case .newHooks, .addDisclosure: return nil
        }
    }

    /// How `after` stands against what `tool` promises of `before`.
    static func judge(_ tool: ScriptTool, before: String, after: String, target: ClosedRange<Int>? = nil) -> RewriteOutcome {
        let words = ReadTime.wordCount(in: after)
        if let allowed = allowedWords(for: tool, sourceWords: ReadTime.wordCount(in: before), target: target) {
            if words < allowed.lowerBound { return .tooShort(words: words, wanted: allowed.lowerBound) }
            if words > allowed.upperBound { return .tooLong(words: words, wanted: allowed.upperBound) }
        }
        let cues = keptCues(before: before, after: after)
        if tool != .translate, cues.had > 0, Double(cues.kept) < (Double(cues.had) * minimumCuesKept(for: tool)).rounded(.up) {
            return .lostCues(had: cues.had, kept: cues.kept)
        }
        return isSame(before, after) ? .unchanged : .kept
    }

    /// The share of the cues a tool must leave: one that cuts words may cut a cue with them.
    private static func minimumCuesKept(for tool: ScriptTool) -> Double {
        switch tool {
        case .shorterAndDirect, .fitToTime, .strongerCTA: 0.3
        default: 0.6
        }
    }

    /// Whether the tool has done its job: what came back is different and within what the tool promises. For "Fix grammar" the same words are the
    /// right answer to a script with nothing wrong.
    func isAcceptable(for tool: ScriptTool) -> Bool {
        switch self {
        case .kept: true
        case .unchanged: tool == .fixGrammar
        case .tooShort, .tooLong, .lostCues: false
        }
    }

    /// What the model is told when its answer missed.
    func correction(for tool: ScriptTool, sourceWords: Int, allowed: ClosedRange<Int>) -> String {
        switch self {
        case .tooShort(let words, _):
            "Your last answer had only \(words) words, but this text has \(sourceWords) and the answer must have between \(allowed.lowerBound) and \(allowed.upperBound). Write it again, with every point kept."
        case .tooLong(let words, _):
            "Your last answer had \(words) words, but the answer must have between \(allowed.lowerBound) and \(allowed.upperBound). Write it again, shorter."
        case .lostCues:
            "Your last answer dropped stage cues that are in square brackets. Write it again and keep every one of them, exactly as it is and where it is."
        case .unchanged, .kept:
            "Your last answer was the same as the text. Write it again, making the change that was asked: \(Self.change(of: tool))"
        }
    }

    /// What "the change that was asked" is, said again.
    private static func change(of tool: ScriptTool) -> String {
        switch tool {
        case .inMyVoice: "use the creator's own words, phrases and rhythm, and change the wording of most sentences, keeping every point."
        case .moreEnergy: "make the sentences punchier and more excited."
        case .moreHuman: "use plain, spoken words instead of the scripted ones."
        case .lessDefensive: "take out the excuses and the defensive lines."
        case .strongerCTA: "make the call to action clearer and more direct."
        case .translate: "translate every sentence."
        default: "change the words as the tool says."
        }
    }

    // MARK: - Words

    /// The same words, whatever the spacing, case and punctuation.
    static func isSame(_ lhs: String, _ rhs: String) -> Bool {
        key(lhs) == key(rhs)
    }

    private static func key(_ text: String) -> String {
        CueParser.stripCues(text).lowercased().unicodeScalars.filter { CharacterSet.alphanumerics.contains($0) }.map(String.init).joined()
    }

    // MARK: - Cues

    /// `after` without the stage cues it was not given. Asked to fix a comma, the model wrote "[Scene: Interior, morning light streaming through curtains…]"
    /// above the script; every bracket is a cue to Cue (it counts them, it shows them, the prompter skips them), so an invented one is a stray line in
    /// the creator's script.
    static func withoutInventedCues(_ after: String, comparedTo before: String) -> String {
        let known = Set(cues(in: before).map(cueKey))
        let cleaned = after.replacing(/\[[^\]]*\]/) { match -> String in
            known.contains(cueKey(String(match.output))) ? String(match.output) : ""
        }
        guard cleaned != after else { return after }
        let lines = cleaned.components(separatedBy: "\n").map { $0.replacing(/[ \t]{2,}/, with: " ").trimmingCharacters(in: .whitespaces) }
        return lines.joined(separator: "\n").replacing(/\n{3,}/, with: "\n\n").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// How many of the cues of `before` are still in `after`.
    private static func keptCues(before: String, after: String) -> (had: Int, kept: Int) {
        let had = cues(in: before).map(cueKey)
        var left = cues(in: after).map(cueKey).reduce(into: [String: Int]()) { $0[$1, default: 0] += 1 }
        var kept = 0
        for cue in had where left[cue, default: 0] > 0 {
            left[cue, default: 0] -= 1
            kept += 1
        }
        return (had.count, kept)
    }

    private static func cues(in text: String) -> [String] {
        text.matches(of: /\[[^\]]*\]/).map { String(text[$0.range]) }
    }

    private static func cueKey(_ cue: String) -> String {
        cue.dropFirst().dropLast().lowercased().split(whereSeparator: \.isWhitespace).joined(separator: " ")
    }
}
