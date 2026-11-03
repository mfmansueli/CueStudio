//
//  LabelLineBreak.swift
//  Cue Studio
//

import Foundation

/// Where a short interface label breaks when it goes on two lines: between two words (at a space, or between the words of a
/// language written without spaces, as Japanese, Chinese or Thai), at the break that leaves the two lines most even. So a long
/// name ("Voce fuori campo", "Dissolvenza incrociata") reads whole on two lines, never split inside a word nor cut (owner,
/// 02/11/2026: no label is ever cut). Pure, so it's tested without a screen.
nonisolated enum LabelLineBreak {
    /// `text` on two even lines joined by a line break, or nil when it can't break: one word ("Unschärfebereich"), or a break
    /// that would leave a line without a letter ("Clip" / "2", "@" / "gebruikersnaam").
    static func twoLines(_ text: String) -> String? {
        let text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.contains(where: \.isNewline) else { return nil }
        var best: (longest: Int, lines: String)?
        for index in breaks(in: text) {
            let first = text[..<index].trimmingCharacters(in: .whitespaces)
            let second = text[index...].trimmingCharacters(in: .whitespaces)
            guard first.contains(where: \.isLetter), second.contains(where: \.isLetter) else { continue }
            let longest = max(first.count, second.count)
            if longest < best?.longest ?? .max {
                best = (longest, first + "\n" + second)
            }
        }
        return best?.lines
    }

    /// Where a second line may begin: after each run of spaces; in a label without spaces, at each word after the first.
    static func breaks(in text: String) -> [String.Index] {
        var indices: [String.Index] = []
        if text.contains(where: \.isWhitespace) {
            var index = text.startIndex
            while index < text.endIndex {
                let next = text.index(after: index)
                if text[index].isWhitespace, next < text.endIndex, !text[next].isWhitespace { indices.append(next) }
                index = next
            }
        } else {
            text.enumerateSubstrings(in: text.startIndex..<text.endIndex, options: [.byWords, .substringNotRequired]) { _, range, _, _ in
                if range.lowerBound > text.startIndex { indices.append(range.lowerBound) }
            }
        }
        return indices
    }
}
