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
    /// The words after which the line goes on a new line (`CaptionCue.lineBreaks`), as it is drawn.
    var breaks: Set<Int> = []

    init(words: [String], index: Int, style: Style, count: Int = 1, breaks: Set<Int> = []) {
        self.words = words
        self.index = index
        self.style = style
        self.count = max(1, count)
        self.breaks = breaks
    }

    /// Every word of the line lit.
    static func wholeLine(_ words: [String], style: Style, breaks: Set<Int> = []) -> WordEmphasis {
        WordEmphasis(words: words, index: 0, style: style, count: words.count, breaks: breaks)
    }

    /// Where the lit words are in `display` (the line as drawn: joined, in capitals when the look asks),
    /// or nil when the words don't make up that line.
    func range(in display: String, uppercased: Bool) -> NSRange? {
        range(in: display, letterCase: uppercased ? .upper : .asTyped)
    }

    /// Where the lit words are in `display`, the line drawn in `letterCase`.
    func range(in display: String, letterCase: CaptionLetterCase) -> NSRange? {
        guard words.indices.contains(index) else { return nil }
        let last = min(words.count - 1, index + count - 1)
        var line = ""
        var start: Int?
        var end = 0
        // The capitals (or small letters) the whole line is drawn in (Turkish "İ", "ı"), word by word.
        let whole = words.joined(separator: " ")
        let locale: Locale? = switch letterCase {
        case .asTyped: nil
        case .upper: TextShaping.capitalsLocale(for: whole)
        case .lower: TextShaping.smallLettersLocale(for: whole)
        }
        for (position, word) in words.enumerated() {
            let shown = letterCase.shown(word, locale: locale)
            if position > 0, breaks.contains(position - 1) {
                line += "\n"
            } else if let previous = line.unicodeScalars.last, let first = shown.unicodeScalars.first,
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

    /// Where each of the line's words at `indices` is in `display` (`text` drawn in `letterCase`); words not found are left out.
    static func ranges(of indices: Set<Int>, in text: String, display: String, letterCase: CaptionLetterCase) -> [Int: NSRange] {
        guard !indices.isEmpty else { return [:] }
        let words = CaptionText.words(in: text)
        let breaks = CaptionText.breaks(in: text)
        var found: [Int: NSRange] = [:]
        for index in indices where words.indices.contains(index) {
            found[index] = WordEmphasis(words: words, index: index, style: .reveal, breaks: breaks).range(in: display, letterCase: letterCase)
        }
        return found
    }
}
