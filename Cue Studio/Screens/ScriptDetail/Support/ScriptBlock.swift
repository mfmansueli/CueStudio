//
//  ScriptBlock.swift
//  Cue Studio
//

import Foundation

/// A paragraph of a script tagged with the structure block it plays (Hook, Body, CTA…).
nonisolated struct ScriptBlock: Hashable, Identifiable, Sendable {
    let index: Int
    let label: String
    let text: String
    let seconds: TimeInterval
    /// False when the previous paragraph belongs to the same block, so the label isn't repeated.
    let showsLabel: Bool

    var id: Int { index }
}
