//
//  DashRewriter.swift
//  Cue Studio
//

import Foundation

/// The dashes Apple Intelligence writes, rewritten into the punctuation of the text's language: Cue writes no dashes in any language (the owner's
/// rule), and the model is told so (`ScriptPromptBuilder.punctuationRule`) but still writes them. Only for what the model wrote
/// (`ScriptPromptBuilder.clean`, `cleanTitle`): the creator's own text is never passed here.
///
/// Each dash is decided inside its sentence: a range ("3–5" → "3 to 5" in the language), a list or dialogue mark at the start of a line (dropped),
/// a pair around an aside (commas), a dash that ends a thought ("…"), and otherwise a comma, a colon or a full stop by what is on each side.
/// Hyphens inside words, the minus sign, "ー", "〜", links, handles, stage cues and the `preserving` phrases are never touched.
nonisolated enum DashRewriter {
    /// The dashes that are punctuation: ‒ – — ― ⸺ ⸻ ﹘ ﹣ and the fullwidth hyphen － (a minus before a number).
    static let dashes: Set<Character> = ["\u{2012}", "\u{2013}", "\u{2014}", "\u{2015}", "\u{2E3A}", "\u{2E3B}", "\u{FE58}", "\u{FE63}", "\u{FF0D}"]

    /// `text` with every dash rewritten; the same text when it has none. Running it again changes nothing.
    /// - Parameters:
    ///   - language: the language of the text (the request's, or a translation's target); nil reads it from the text.
    ///   - preserving: the creator's words the model had to repeat (catchphrases, a brand's line, a sentence of theirs it kept): left as they are.
    static func rewrite(_ text: String, language: Locale.Language?, preserving: [String] = []) -> String {
        guard mayContainDash(text) else { return text }
        let characters = Array(text)
        let mask = ProtectedSpans.mask(in: text, preserving: preserving.filter(mayContainDash))
        let marks = found(in: characters, mask: mask)
        guard !marks.isEmpty else { return text }
        let language = language ?? LanguageDetector.dominantLanguage(in: text)
        let pass = Pass(
            characters: characters, mask: mask, sentences: sentences(in: characters).ranges,
            punctuation: .forLanguage(language), rangeTemplate: rangeTemplate(for: language)
        )
        return pass.rewritten(marks)
    }

    /// What can be shown of a text still being written: the sentences already finished, rewritten, and the one being written up to its first
    /// dash, which waits until the sentence ends (with what follows it). Always the start of what `rewrite` gives once the text is complete, so
    /// a word never changes after it appears. Give the language: read from a few words it could change from one snapshot to the next.
    static func displayable(_ partial: String, language: Locale.Language?, preserving: [String] = []) -> String {
        let characters = Array(partial)
        let cut = sentences(in: characters).confirmedEnd
        let tail = Array(characters[cut...])
        let mask = Array(ProtectedSpans.mask(in: partial, preserving: preserving.filter(mayContainDash))[cut...])
        let finished = rewrite(String(characters[..<cut]), language: language, preserving: preserving)
        var shown: [Character] = []
        var from = 0
        if let first = tail.firstIndex(where: { !$0.isWhitespace }), !mask[first],
           let after = markEnd(in: tail, at: first, lineStart: isLineStart(cut + first, in: characters)) {
            // A list or dialogue mark is dropped as soon as the words after it show; until then nothing after it shows.
            guard after < tail.count else { return finished + trimmed(tail[..<first]) }
            shown = Array(tail[..<first])
            from = after
        }
        var stop = tail.count
        if let open = ProtectedSpans.unfinishedStart(in: partial), open >= cut { stop = max(from, open - cut) }
        if let dash = (from..<stop).first(where: { !mask[$0] && mayStartDash(at: $0, in: tail) }) { stop = dash }
        if from < stop { shown += tail[from..<stop] }
        return finished + trimmed(shown[...])
    }

    /// Whether `text` still holds a dash outside the protected spans.
    static func containsDash(_ text: String, preserving: [String] = []) -> Bool {
        guard mayContainDash(text) else { return false }
        let characters = Array(text)
        let mask = ProtectedSpans.mask(in: text, preserving: preserving.filter(mayContainDash))
        return found(in: characters, mask: mask).contains { !Pass.isMinus($0, in: characters) }
    }

    /// The sentences of `text` (the creator's) that hold a dash: when the model edits that text, a sentence it kept word for word keeps its dash.
    static func sentencesWithDashes(in text: String) -> [String] {
        let characters = Array(text)
        return sentences(in: characters).ranges
            .map { String(characters[$0]).trimmingCharacters(in: .whitespaces) }
            .filter { $0.contains(where: \.isLetter) && containsDash($0) }
    }

    // MARK: - Finding

    /// One dash: its characters, and whether it starts its line (a list or dialogue mark).
    struct Dash: Equatable {
        var start: Int
        var end: Int
        var isLineMark: Bool
    }

    /// A quick look before any work: most answers have no dash at all.
    private static func mayContainDash(_ text: String) -> Bool {
        text.contains(where: dashes.contains) || text.contains("- ")
    }

    /// The dashes outside the protected spans, in order. A run ("——", "— —") is one dash. A hyphen counts as one only between two words with a
    /// space on each side ("word - word") or as a list mark ("- " at the start of a line): never inside a word, between numbers or before a flag.
    static func found(in characters: [Character], mask: [Bool]) -> [Dash] {
        var result: [Dash] = []
        var index = 0
        while index < characters.count {
            defer { index += 1 }
            guard !mask[index] else { continue }
            if dashes.contains(characters[index]) {
                var end = index + 1
                var next = index + 1
                while next < characters.count, !mask[next], dashes.contains(characters[next]) || characters[next] == " " {
                    if dashes.contains(characters[next]) { end = next + 1 }
                    next += 1
                }
                result.append(Dash(start: index, end: end, isLineMark: isLineStart(index, in: characters)))
                index = end - 1
            } else if characters[index] == "-", let dash = hyphenDash(at: index, in: characters) {
                result.append(dash)
            }
        }
        return result
    }

    private static func hyphenDash(at index: Int, in characters: [Character]) -> Dash? {
        guard index + 1 < characters.count, characters[index + 1] == " " else { return nil }
        if isLineStart(index, in: characters) { return Dash(start: index, end: index + 1, isLineMark: true) }
        guard index > 0, characters[index - 1] == " " else { return nil }
        let before = characters[..<index].last { $0 != " " }
        let after = characters[(index + 1)...].first { $0 != " " }
        guard before?.isLetter == true, after?.isLetter == true else { return nil }
        return Dash(start: index, end: index + 1, isLineMark: false)
    }

    /// Only whitespace between the start of the line and `index`.
    static func isLineStart(_ index: Int, in characters: [Character]) -> Bool {
        var position = index
        while position > 0 {
            let previous = characters[position - 1]
            if previous.isNewline { return true }
            guard previous.isWhitespace else { return false }
            position -= 1
        }
        return true
    }

    /// Where the words after a list or dialogue mark at `index` start; nil when there is no mark there, `characters.count` when nothing follows it yet.
    private static func markEnd(in characters: [Character], at index: Int, lineStart: Bool) -> Int? {
        var end: Int
        if dashes.contains(characters[index]) {
            end = index + 1
            while end < characters.count, dashes.contains(characters[end]) || characters[end] == " " { end += 1 }
        } else if characters[index] == "-", lineStart {
            guard index + 1 < characters.count else { return characters.count }
            guard characters[index + 1] == " " else { return nil }
            end = index + 1
            while end < characters.count, characters[end] == " " { end += 1 }
        } else {
            return nil
        }
        return end
    }

    /// A dash, or a hyphen after a space that the next characters could make one, at `index` of a sentence still being written.
    private static func mayStartDash(at index: Int, in characters: [Character]) -> Bool {
        if dashes.contains(characters[index]) { return true }
        guard characters[index] == "-", index > 0, characters[index - 1] == " " else { return false }
        return index + 1 == characters.count || characters[index + 1] == " "
    }

    private static func trimmed(_ characters: ArraySlice<Character>) -> String {
        var end = characters.endIndex
        while end > characters.startIndex, characters[end - 1].isWhitespace { end -= 1 }
        return String(characters[characters.startIndex..<end])
    }

    // MARK: - Sentences

    static let terminators: Set<Character> = [".", "!", "?", "…", "。", "！", "？", "।", "؟"]
    /// Chinese and Japanese end a sentence with these whatever follows.
    private static let strongTerminators: Set<Character> = ["。", "！", "？"]
    static let closers: Set<Character> = ["\"", "'", "”", "’", "»", "」", "』", ")", "）"]

    /// The sentences as ranges of `Character` offsets (a line break always ends one; the space after a full stop starts the next), and where the
    /// last sentence known to be finished ends: a full stop with a space after it, a line break, or 。！？.
    static func sentences(in characters: [Character]) -> (ranges: [Range<Int>], confirmedEnd: Int) {
        var ranges: [Range<Int>] = []
        var start = 0
        var index = 0
        var confirmed = 0
        func close(at end: Int, next: Int) {
            if start < end { ranges.append(start..<end) }
            start = next
            confirmed = next
            index = next
        }
        while index < characters.count {
            if characters[index].isNewline {
                close(at: index, next: index + 1)
                continue
            }
            guard terminators.contains(characters[index]) else {
                index += 1
                continue
            }
            var end = index
            while end < characters.count, terminators.contains(characters[end]) { end += 1 }
            if characters[index..<end].contains(where: strongTerminators.contains) {
                close(at: end, next: end)
                continue
            }
            var after = end
            while after < characters.count, closers.contains(characters[after]) { after += 1 }
            if after < characters.count, characters[after].isWhitespace {
                close(at: after, next: after)
            } else {
                index = end
            }
        }
        if start < characters.count { ranges.append(start..<characters.count) }
        return (ranges, confirmed)
    }

    // MARK: - Ranges

    /// "%1$@ to %2$@" in the text's language: de "%1$@ bis %2$@", ja "%1$@〜%2$@" (English until the catalog has the language).
    static func rangeTemplate(for language: Locale.Language?) -> String {
        String(
            localized: "%1$@ to %2$@", writtenIn: language.flatMap(CueLanguage.matching(language:)),
            comment: "A range of numbers or lengths (“3 to 5”, “1:00 to 1:30”). Not the countdown “%@ to %@”."
        )
    }
}
