//
//  ScriptBlocks.swift
//  Cue Studio
//

import Foundation

/// Splits a script into its structure blocks and times them.
nonisolated enum ScriptBlocks {
    /// Viewers decide in the first 3 seconds; a little slack before warning.
    static let hookTarget: TimeInterval = 3.5

    static func blocks(for text: String, structure: ScriptStructure, speed: Double) -> [ScriptBlock] {
        let paragraphs = CueParser.paragraphs(in: text)
        var blocks: [ScriptBlock] = []
        for (index, paragraph) in paragraphs.enumerated() {
            let label = structure.blockLabel(forParagraph: index, of: paragraphs.count)
            blocks.append(ScriptBlock(
                index: index,
                label: label,
                text: paragraph,
                seconds: ReadTime.seconds(for: paragraph, speed: speed),
                showsLabel: index == 0 || blocks[index - 1].label != label
            ))
        }
        return blocks
    }

    /// Consecutive blocks with the same label merged into one chip.
    static func summaries(of blocks: [ScriptBlock]) -> [BlockSummary] {
        var summaries: [BlockSummary] = []
        for block in blocks {
            if let last = summaries.last, last.label == block.label {
                summaries[summaries.count - 1].seconds += block.seconds
            } else {
                summaries.append(BlockSummary(label: block.label, seconds: block.seconds, isOpening: block.index == 0, firstParagraph: block.index))
            }
        }
        return summaries
    }

    /// How long the hook runs when it is over the target. Serious formats have no hook.
    static func hookOverrun(in blocks: [ScriptBlock], structure: ScriptStructure) -> TimeInterval? {
        guard !structure.isSerious, let opening = blocks.first, opening.seconds > hookTarget else { return nil }
        return opening.seconds
    }
}
