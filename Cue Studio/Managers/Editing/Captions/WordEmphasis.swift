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
    /// How many words from `index` are lit: 1 for the word being said, every word for a line lit whole
    /// (`CaptionLineStyle.isEmphasized`).
    var count = 1

    init(words: [String], index: Int, style: Style, count: Int = 1) {
        self.words = words
        self.index = index
        self.style = style
        self.count = max(1, count)
    }

    /// Every word of the line lit.
    static func wholeLine(_ words: [String], style: Style) -> WordEmphasis {
        WordEmphasis(words: words, index: 0, style: style, count: words.count)
    }

    /// Where the lit words are in `display` (the line as drawn: joined, in capitals when the look asks),
    /// or nil when the words don't make up that line.
    func range(in display: String, uppercased: Bool) -> NSRange? {
        guard words.indices.contains(index) else { return nil }
        let last = min(words.count - 1, index + count - 1)
        var line = ""
        var start: Int?
        var end = 0
        // The capitals the whole line is drawn in (Turkish "İ"), word by word.
        let locale = uppercased ? TextShaping.capitalsLocale(for: words.joined(separator: " ")) : nil
        for (position, word) in words.enumerated() {
            let shown = uppercased ? TextShaping.uppercased(word, locale: locale) : word
            if let previous = line.unicodeScalars.last, let first = shown.unicodeScalars.first,
               !(WordSegmenter.isUnspaced(previous) && WordSegmenter.isUnspaced(first)) {
                line += " "
            }
            let location = (line as NSString).length
            line += shown
            if position == index { start = location }
            if position == last { end = (line as NSString).length }
        }
        guard line == display, let start else { return nil }
        return NSRange(location: start, length: end - start)
    }
}
