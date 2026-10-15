//
//  ScriptRepetition.swift
//  Cue Studio
//

import Foundation

/// How much a script says the same thing twice, measured on its spoken words (stage cues left out) in runs of three: the small model pads a script
/// it was asked to make long by saying a block again in other order ("Drink water first. … So, drink water first."). Pure and cheap, in any language
/// the tokenizer reads (`WritingText`).
nonisolated enum ScriptRepetition {
    /// The share of the script's three-word runs that are said more than once (0: none, 1: all of them).
    static func repeatedShare(in text: String, language: String? = nil) -> Double {
        let runs = trigrams(of: text, language: language)
        guard !runs.isEmpty else { return 0 }
        return 1 - Double(Set(runs).count) / Double(runs.count)
    }

    /// For each block after the first, the share of its three-word runs already said in an earlier block (the first block is 0).
    static func echoes(in blocks: [String], language: String? = nil) -> [Double] {
        var said = Set<String>()
        return blocks.map { block in
            let runs = trigrams(of: block, language: language)
            let echo = runs.isEmpty || said.isEmpty ? 0 : Double(runs.filter(said.contains).count) / Double(runs.count)
            said.formUnion(runs)
            return echo
        }
    }

    /// The three-word runs of the spoken words, lowercased.
    static func trigrams(of text: String, language: String? = nil) -> [String] {
        let words = WritingText.words(in: CueParser.stripCues(text), language: language).map(\.key)
        guard words.count >= 3 else { return [] }
        return (0...(words.count - 3)).map { words[$0...($0 + 2)].joined(separator: " ") }
    }
}
