//
//  ScriptExpansion.swift
//  Cue Studio
//

import Foundation

/// Making a script that came out too short as long as it was asked to be, or one that ran far over as short, one block at a time. The model on the
/// iPhone writes about half of the words it is asked for and, told its draft is short, writes it short again (measured on an iPhone 15 Pro: 54 words
/// for 150 asked, then 64 to 86 on the second try). Asked to change a single block to a size, it does it. This plans which blocks and to how many
/// words; the model call is `ScriptAIService.expandingIfShort`.
nonisolated enum ScriptExpansion {
    /// A script with fewer words than this share of its minimum is expanded.
    static let trigger = 0.7
    /// The words each block is asked to reach, as a share of the minimum, spread over the blocks (the opening and the close are the shortest).
    static let goal = 1.0

    /// A script with more words than this many times its maximum is shortened.
    static let overshoot = 1.25

    enum Direction: Sendable {
        case longer, shorter
    }

    /// One block to lengthen or shorten: where it is, how long it is and how long it should be.
    struct Step: Hashable, Sendable {
        let index: Int
        let words: Int
        let target: Int
        let isShorter: Bool

        var direction: Direction { isShorter ? .shorter : .longer }
    }

    /// The blocks of a script as the prompter shows them: paragraphs.
    static func blocks(of text: String) -> [String] {
        text.components(separatedBy: "\n\n").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
    }

    /// The words of a block, without its stage cues.
    static func words(in text: String) -> Int {
        ReadTime.wordCount(in: CueParser.stripCues(text))
    }

    /// The blocks to change for a script that must have between `minimumWords` and `maximumWords`: the short ones of a script with far fewer words than
    /// the minimum are lengthened, the long ones of a script with far more than the maximum are shortened; none when it is in range, or when nothing
    /// in it is worth changing.
    static func steps(for text: String, minimumWords: Int, maximumWords: Int = .max) -> [Step] {
        let blocks = blocks(of: text)
        guard !blocks.isEmpty, minimumWords > 0 else { return [] }
        let total = blocks.reduce(0) { $0 + words(in: $1) }
        let weights = blocks.indices.map { index -> Double in
            guard blocks.count > 2 else { return 1 }
            return index == 0 ? 0.7 : (index == blocks.count - 1 ? 0.6 : 1)
        }
        let sum = weights.reduce(0, +)
        if Double(total) < Double(minimumWords) * trigger {
            let wanted = Double(minimumWords) * goal
            return blocks.indices.compactMap { index in
                let target = Int((wanted * weights[index] / sum).rounded())
                let current = words(in: blocks[index])
                // A block already near its share is left as it is: lengthening it would only repeat it.
                return Double(current) < Double(target) * 0.8 ? Step(index: index, words: current, target: target, isShorter: false) : nil
            }
        }
        if maximumWords < .max, Double(total) > Double(maximumWords) * overshoot {
            let wanted = Double(maximumWords) * 0.95
            return blocks.indices.compactMap { index in
                let target = Int((wanted * weights[index] / sum).rounded())
                let current = words(in: blocks[index])
                return Double(current) > Double(target) * 1.2 ? Step(index: index, words: current, target: target, isShorter: true) : nil
            }
        }
        return []
    }

    /// The script with `replacements` (by block index) in place of the blocks they lengthen.
    static func assembling(_ blocks: [String], replacing replacements: [Int: String]) -> String {
        blocks.enumerated().map { replacements[$0.offset] ?? $0.element }.joined(separator: "\n\n")
    }
}
