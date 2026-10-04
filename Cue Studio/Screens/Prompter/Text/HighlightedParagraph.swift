//
//  HighlightedParagraph.swift
//  Cue Studio
//

import SwiftUI

/// A paragraph with its spoken words lit. While recognition follows the voice, the text rests at 42% and the
/// words just said come up to full, the newest in the accent colour, so the eye sees where the voice is.
enum HighlightedParagraph {
    /// Unread and read-long-ago words.
    static let restingOpacity = 0.42

    /// - Parameters:
    ///   - text: the paragraph as drawn (cue tags keep their own colours).
    ///   - lit: the words to light (indices into the paragraph's spans) and the newest one.
    static func styled(
        _ text: AttributedString, spans: [WordSpan], lit: (words: Range<Int>, newest: Int?)?, color: Color, accent: Color
    ) -> AttributedString {
        var result = text
        // Speech at rest; the cue tags carry a colour already.
        let speech = result.runs.filter { $0.foregroundColor == nil }.map(\.range)
        for range in speech { result[range].foregroundColor = color.opacity(restingOpacity) }
        guard let lit else { return result }
        for index in lit.words where spans.indices.contains(index) {
            guard let range = range(of: spans[index].characters, in: result) else { continue }
            result[range].foregroundColor = index == lit.newest ? accent : color
        }
        return result
    }

    private static func range(of characters: Range<Int>, in text: AttributedString) -> Range<AttributedString.Index>? {
        let view = text.characters
        guard let lower = view.index(view.startIndex, offsetBy: characters.lowerBound, limitedBy: view.endIndex),
              let upper = view.index(view.startIndex, offsetBy: characters.upperBound, limitedBy: view.endIndex),
              lower < upper else { return nil }
        return lower..<upper
    }
}
