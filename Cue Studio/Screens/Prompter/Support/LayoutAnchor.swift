//
//  LayoutAnchor.swift
//  Cue Studio
//

import Foundation

/// The word to put on the reading guide when the prompter swaps between Selfie and Studio, held
/// while the layout of the mode entered reports its measures.
nonisolated struct LayoutAnchor: Sendable {
    /// How long, in seconds, the other layout has to report its measures.
    static let settling: TimeInterval = 0.6

    let words: ScriptWords
    let word: Int
    /// On the prompter's clock.
    let until: TimeInterval
}
