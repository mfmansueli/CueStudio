//
//  WordEmphasis.swift
//  Cue Studio
//

import Foundation

/// The word being said in a caption line, and how it stands out: another color, or a box behind
/// it.
nonisolated struct WordEmphasis: Hashable, Sendable {
    enum Style: Hashable, Sendable {
        case color(OverlayColor)
        case box(fill: OverlayColor, text: OverlayColor)
        /// Words appear as they are said: those after this one aren't drawn yet.
        case reveal
    }

    /// The line's words, as heard (the line's text is them joined).
    let words: [String]
    /// The word being said.
    let index: Int
    let style: Style

    /// Where the word is in `display` (the line as drawn: joined, in capitals when the look asks),
    /// or nil when the words don't make up that line.
    func range(in display: String, uppercased: Bool) -> NSRange? {
        guard words.indices.contains(index) else { return nil }
        var line = ""
        var found: NSRange?
        for (position, word) in words.enumerated() {
            let shown = uppercased ? word.uppercased() : word
            if let last = line.unicodeScalars.last, let first = shown.unicodeScalars.first,
               !(WordSegmenter.isUnspaced(last) && WordSegmenter.isUnspaced(first)) {
                line += " "
            }
            let start = (line as NSString).length
            line += shown
            if position == index { found = NSRange(location: start, length: (shown as NSString).length) }
        }
        return line == display ? found : nil
    }
}
