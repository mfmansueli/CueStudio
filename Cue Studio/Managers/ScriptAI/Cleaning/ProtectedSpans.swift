//
//  ProtectedSpans.swift
//  Cue Studio
//

import Foundation

/// The parts of a text `DashRewriter` never touches, whatever they hold: links, e-mail addresses, @handles and #tags, stage cues, and the
/// creator's own words the model had to repeat (a catchphrase, a brand's line, a sentence of theirs it kept as it was).
nonisolated enum ProtectedSpans {
    /// For each `Character` of `text`, whether it lies in a protected span.
    static func mask(in text: String, preserving: [String]) -> [Bool] {
        var mask = [Bool](repeating: false, count: text.count)
        func protect(_ range: Range<String.Index>) {
            let start = text.distance(from: text.startIndex, to: range.lowerBound)
            let end = text.distance(from: text.startIndex, to: range.upperBound)
            for offset in start..<end { mask[offset] = true }
        }
        for match in text.matches(of: /https?:\/\/\S+|www\.\S+/) { protect(match.range) }
        for match in text.matches(of: /[A-Za-z0-9._%+\-]+@[A-Za-z0-9.\-]+\.[A-Za-z]{2,}/) { protect(match.range) }
        for match in text.matches(of: /[@#][\w.]+/) { protect(match.range) }
        for match in text.matches(of: /\[[^\]\n]{1,40}\]/) { protect(match.range) }
        for phrase in preserving {
            let phrase = phrase.trimmingCharacters(in: .whitespacesAndNewlines)
            guard phrase.contains(where: \.isLetter) else { continue }
            var from = text.startIndex
            while from < text.endIndex, let found = text.range(of: phrase, options: [.caseInsensitive, .diacriticInsensitive], range: from..<text.endIndex) {
                protect(found)
                from = found.upperBound
            }
        }
        return mask
    }

    /// Where a span that is still arriving begins at the end of `text` (a cue whose bracket isn't closed, a link still being written), as a
    /// `Character` offset; nil when the text doesn't end inside one. Shown half written, it could be taken for words to rewrite.
    static func unfinishedStart(in text: String) -> Int? {
        var starts: [Int] = []
        if let open = text.lastIndex(of: "["), !text[open...].contains("]"), !text[open...].contains("\n"), text.distance(from: open, to: text.endIndex) <= 41 {
            starts.append(text.distance(from: text.startIndex, to: open))
        }
        for match in text.matches(of: /https?:\/\/\S*|www\.\S*|[@#][\w.]*/) where match.range.upperBound == text.endIndex {
            starts.append(text.distance(from: text.startIndex, to: match.range.lowerBound))
        }
        return starts.min()
    }
}
