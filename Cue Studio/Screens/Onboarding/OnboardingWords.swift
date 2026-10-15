//
//  OnboardingWords.swift
//  Cue Studio
//

import Foundation

/// The pieces a first-flight text arrives in, one at a time (the welcome's title, the practice script on 1.4): the words between spaces, or,
/// in a language written without them (Japanese, Chinese, Thai), each dictionary word with what follows it up to the next, so no punctuation
/// is lost and the line can break between them. The chapters redraw every frame while the pieces arrive, so each text is cut once.
@MainActor
enum OnboardingWords {
    static func pieces(of text: String) -> [String] {
        if let cut = cuts[text] { return cut }
        let cut = cutting(text)
        cuts[text] = cut
        return cut
    }

    /// Whether the pieces go side by side with no space between them.
    static func isUnspaced(_ text: String) -> Bool {
        WordSegmenter.containsUnspacedScript(text)
    }

    private static var cuts: [String: [String]] = [:]

    private static func cutting(_ text: String) -> [String] {
        guard isUnspaced(text) else {
            return text.split(whereSeparator: \.isWhitespace).map(String.init)
        }
        let starts = WordSegmenter.wordRanges(in: text).map(\.lowerBound).dropFirst()
        var pieces: [String] = []
        var from = text.startIndex
        for start in starts where start > from {
            pieces.append(String(text[from..<start]))
            from = start
        }
        pieces.append(String(text[from...]))
        return pieces.map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
    }
}
