//
//  ScriptHook.swift
//  Cue Studio
//

import Foundation

/// The hook of a script: what a viewer hears in the first seconds and decides on. A short first paragraph (Apple Intelligence's hook block, a
/// line the creator wrote on its own) is the hook whole; a longer one (Ultra AI's paragraphs of two to four sentences, a script written in one
/// block) opens with its first sentence, and the next one too when the first is a word or two ("Okay, real talk."). A disclosure line is never the
/// hook, and the cues around it stay where they are. The tip that a hook runs long, "3 new hooks" and "✦ Shape" all read the hook here.
nonisolated enum ScriptHook {
    /// A first paragraph of this many words or fewer is the hook whole.
    static let paragraphWords = 25
    /// A first sentence this short is said with the next one.
    static let shortSentenceWords = 3

    /// Where the hook's words are in `text`, without the cues before and after it; nil for a text with nothing to say.
    static func range(in text: String) -> Range<String.Index>? {
        guard let paragraph = openingParagraph(in: text) else { return nil }
        let line = text[paragraph]
        let end: String.Index
        if ReadTime.wordCount(in: CueParser.stripCues(String(line))) <= paragraphWords {
            end = paragraph.upperBound
        } else {
            var sentences = ScriptParagraphs.sentences(of: String(line))
            if sentences.count > 1, ReadTime.wordCount(in: CueParser.stripCues(sentences[0])) <= shortSentenceWords {
                sentences[0] += sentences.remove(at: 1)
            }
            let length = sentences.first?.count ?? line.count
            end = text.index(paragraph.lowerBound, offsetBy: length, limitedBy: paragraph.upperBound) ?? paragraph.upperBound
        }
        return trimmed(paragraph.lowerBound..<end, in: text)
    }

    /// The hook's words (its inner cues included), or "" for a text with nothing to say.
    static func text(of text: String) -> String {
        range(in: text).map { String(text[$0]) } ?? ""
    }

    /// `text` with its hook replaced by `hook` and everything else (a disclosure, the cues around the hook, the rest of the paragraph) as it was.
    static func replacing(in text: String, with hook: String) -> String {
        let hook = hook.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let range = range(in: text) else { return hook }
        var replaced = text
        replaced.replaceSubrange(range, with: hook)
        return replaced
    }

    /// The first line with words to say that isn't a disclosure; a script that is only a disclosure has it as its opening.
    private static func openingParagraph(in text: String) -> Range<String.Index>? {
        var lines: [Range<String.Index>] = []
        var start = text.startIndex
        while start < text.endIndex {
            let end = text[start...].firstIndex(of: "\n") ?? text.endIndex
            if !CueParser.stripCues(String(text[start..<end])).trimmingCharacters(in: .whitespaces).isEmpty {
                lines.append(start..<end)
            }
            start = end < text.endIndex ? text.index(after: end) : end
        }
        return lines.first { !ScriptTextEditing.isDisclosure(String(text[$0])) } ?? lines.first
    }

    /// `range` without the spaces and cues at its two ends.
    private static func trimmed(_ range: Range<String.Index>, in text: String) -> Range<String.Index>? {
        var lower = range.lowerBound
        var upper = range.upperBound
        while lower < upper {
            if text[lower].isWhitespace {
                lower = text.index(after: lower)
            } else if text[lower] == "[", let close = text[lower..<upper].firstIndex(of: "]") {
                lower = text.index(after: close)
            } else {
                break
            }
        }
        while upper > lower {
            let last = text.index(before: upper)
            if text[last].isWhitespace {
                upper = last
            } else if text[last] == "]", let open = text[lower..<last].lastIndex(of: "[") {
                upper = open
            } else {
                break
            }
        }
        return lower < upper ? lower..<upper : nil
    }
}
