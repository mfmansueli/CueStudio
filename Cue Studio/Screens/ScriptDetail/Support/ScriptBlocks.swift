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

    /// The editor's version of `blocks`: every paragraph, the empty one being typed in included, with
    /// the label it will play and, on the first of each block, the block's read time.
    static func editorLabels(for paragraphs: [String], structure: ScriptStructure, speed: Double) -> [EditorBlockLabel] {
        let labels = paragraphs.indices.map { structure.blockLabel(forParagraph: $0, of: paragraphs.count) }
        let seconds = paragraphs.map { ReadTime.seconds(for: $0, speed: speed) }
        return paragraphs.indices.map { index in
            let starts = index == 0 || labels[index - 1] != labels[index]
            guard starts else { return EditorBlockLabel(label: labels[index], showsLabel: false, groupSeconds: nil) }
            var total: TimeInterval = 0
            var next = index
            while next < paragraphs.count, labels[next] == labels[index] {
                total += seconds[next]
                next += 1
            }
            return EditorBlockLabel(label: labels[index], showsLabel: true, groupSeconds: total)
        }
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
