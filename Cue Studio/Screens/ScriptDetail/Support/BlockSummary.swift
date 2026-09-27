//
//  BlockSummary.swift
//  Cue Studio
//

import Foundation

/// One chip of the block strip: consecutive paragraphs of the same block, merged.
nonisolated struct BlockSummary: Hashable, Identifiable, Sendable {
    let label: String
    var seconds: TimeInterval
    /// The opening block, where the hook lives.
    let isOpening: Bool
    let firstParagraph: Int

    var id: Int { firstParagraph }
}
