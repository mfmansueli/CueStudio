//
//  ScriptStructure.swift
//  Cue Studio
//

import Foundation

/// The shape of a script format: its blocks, tones, editing tools and hook ideas.
nonisolated struct ScriptStructure: Hashable, Sendable {
    let label: String
    /// Block names in order. The first labels the opening paragraph, the last the closing one.
    let blocks: [String]
    let tones: [Tone]
    let tools: [ScriptTool]
    let hooks: [String]
    /// Serious formats (apologies, statements) never get hooks, hype or calls to action.
    let isSerious: Bool

    /// Used by scripts without a format.
    static let generic = ScriptStructure(
        label: String(localized: "Script"),
        blocks: [String(localized: "Hook"), String(localized: "Body"), String(localized: "CTA")],
        tones: [.casual, .energetic, .expert, .funny],
        tools: [.newHooks, .fitToTime, .moreEnergy, .fixGrammar, .translate],
        hooks: [
            String(localized: "Okay, real talk — this one matters."),
            String(localized: "Nobody talks about this, so I will."),
            String(localized: "Stop scrolling for ten seconds."),
            String(localized: "I tested this so you don't have to."),
        ],
        isSerious: false
    )

    /// Label for a block index given the number of paragraphs: the first paragraph is always the
    /// opening block, the last one the closing block, the ones in between walk the middle blocks.
    func blockLabel(forParagraph index: Int, of count: Int) -> String {
        guard let first = blocks.first, let last = blocks.last else { return "" }
        if index == 0 { return first }
        if index == count - 1 && count > 1 { return last }
        return blocks[min(index, max(0, blocks.count - 2))]
    }
}
