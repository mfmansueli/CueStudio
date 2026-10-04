//
//  PrompterHighlighter.swift
//  Cue Studio
//

import Foundation

/// The words Voice following lights as they are said. The view model keeps it up to date (the position of
/// recognition, the script's words, whether recognition follows at all); the text reads `highlight`, so only
/// the text redraws when a word is heard.
@Observable
final class PrompterHighlighter {
    /// True while recognition follows the words. Steady scrolling and the level-only fallback light nothing.
    var isActive = false
    /// The next word to read, as a token index in the script.
    var position = 0
    var words = ScriptWords(text: "")

    @ObservationIgnored private var cache: (paragraphs: [String], showsCues: Bool, language: CueLanguage?, spans: [[WordSpan]])?

    /// What to light, or nil when nothing is to be lit.
    func highlight(paragraphs: [String], showsCues: Bool, language: CueLanguage?) -> WordHighlight? {
        guard isActive, words.count > 0, words.paragraphStarts.count == paragraphs.count + 1 else { return nil }
        if let cache, cache.paragraphs == paragraphs, cache.showsCues == showsCues, cache.language == language {
            return WordHighlight(position: position, spans: cache.spans, starts: words.paragraphStarts)
        }
        let spans = paragraphs.map { WordSpans.spans(in: $0, showsCues: showsCues, language: language) }
        cache = (paragraphs, showsCues, language, spans)
        return WordHighlight(position: position, spans: spans, starts: words.paragraphStarts)
    }
}
