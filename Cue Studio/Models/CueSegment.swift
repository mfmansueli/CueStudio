//
//  CueSegment.swift
//  Cue Studio
//

import Foundation

/// A run of script text: either words to say or a stage cue like `[pause]`.
nonisolated struct CueSegment: Hashable, Sendable {
    enum Kind: Hashable, Sendable {
        case speech
        case cue
    }

    let kind: Kind
    /// For cues, the text without brackets.
    let text: String
}
