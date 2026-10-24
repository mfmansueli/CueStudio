//
//  CaptionFormat.swift
//  Cue Studio
//

import Foundation

/// How the caption lines are cut into what shows at once (`CaptionBlocking`), measured with the style's own type so a line
/// always fits without shrinking: the word being said alone, a short phrase (one line when it can, two at most), or blocks
/// of up to two balanced lines. The words, their corrections and their times stay the same in every format: a format only
/// groups them. Nil in `CaptionSettings`: the lines as they were made (edits from before formats).
nonisolated enum CaptionFormat: String, LenientChoice, CaseIterable, Identifiable, Sendable {
    /// Read in place of a value a newer version of Cue added (`LenientChoice`).
    static let fallback = CaptionFormat.phrase

    /// The word being said, replaced by the next, in the same place.
    case oneWord
    /// A group that makes sense, on one line when it can, on two at most. New captions start here.
    case phrase
    /// Longer blocks of up to two lines, broken evenly.
    case twoLines

    var id: String { rawValue }

    var label: String {
        switch self {
        case .oneWord: String(localized: "One word")
        case .phrase: String(localized: "Short phrase")
        case .twoLines: String(localized: "Two lines")
        }
    }

    /// Lines a block may take on screen.
    var maxLines: Int {
        switch self {
        case .oneWord: 1
        case .phrase, .twoLines: 2
        }
    }

    /// The longest a block stays on screen before it breaks, wherever it can.
    var longestBlock: TimeInterval {
        switch self {
        case .oneWord: 1.2
        case .phrase: 3.5
        case .twoLines: 6
        }
    }
}
