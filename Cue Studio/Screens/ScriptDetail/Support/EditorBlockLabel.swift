//
//  EditorBlockLabel.swift
//  Cue Studio
//

import Foundation

/// The block a paragraph plays while it's being written (Hook, Body, CTA…), and the seconds of
/// the whole block on its first paragraph, where the label shows.
nonisolated struct EditorBlockLabel: Hashable, Sendable {
    let label: String
    /// False when the paragraph before it belongs to the same block.
    let showsLabel: Bool
    /// The block's read time, only on the paragraph that shows the label.
    let groupSeconds: TimeInterval?
}
