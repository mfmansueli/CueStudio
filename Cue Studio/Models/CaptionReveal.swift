//
//  CaptionReveal.swift
//  Cue Studio
//

import Foundation

/// Whether a caption shows whole while it is said, or word by word as each is said (Caption style › Animation › Reveal).
nonisolated enum CaptionReveal: String, LenientChoice, CaseIterable, Identifiable, Sendable {
    /// Read in place of a value a newer version of Cue added (`LenientChoice`).
    static let fallback = CaptionReveal.line

    case line, words

    var id: String { rawValue }

    var label: String {
        switch self {
        case .line: String(localized: "Whole line")
        case .words: String(localized: "Word by word")
        }
    }

    var systemImage: String {
        switch self {
        case .line: "text.alignleft"
        case .words: "text.word.spacing"
        }
    }
}
