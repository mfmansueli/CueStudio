//
//  CueRestorer.swift
//  Cue Studio
//

import Foundation

/// Puts back the stage cues of the creator's script that a rewrite dropped, each where it was: after the sentence it followed when the rewrite kept
/// that sentence in some form, before the one it came before otherwise, and at the same point of the paragraph (or of the script, when the paragraphs
/// changed) when neither is left. Measured on the iPhone (ScriptToolsQualityDeviceTests, 01/11/2026), the device model dropped every cue when asked
/// to shorten a script with eight ("cues 8→0") and, asked to sound more human, dropped enough of them twice that the script was left as written; a
/// cue is the creator's direction to themselves ("[pause]", "[look at camera]"), not the model's to keep or lose. Rules only: the words of the
/// rewrite never change, and a cue it kept is not added again.
nonisolated enum CueRestorer {
    /// `after` with the cues of `before` it doesn't have.
    static func restoring(_ after: String, from before: String) -> String {
        let source = layout(of: before)
        guard !source.cues.isEmpty, !CueParser.stripCues(after).trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return after }
        let result = layout(of: after)
        let missing = unmatched(source.cues, against: result.cues)
        guard !missing.isEmpty else { return after }
        let sameParagraphs = source.paragraphs.count == result.paragraphs.count
        // The cues to add at each point of `after`: (paragraph, boundary) → cues in the order they were written.
        var additions: [Point: [String]] = [:]
        for cue in missing {
            additions[result.point(for: cue, inSameParagraph: sameParagraphs), default: []].append(cue.text)
        }
        return result.text(adding: additions)
    }

    // MARK: - Layout

    /// A place between sentences: before the first sentence of a paragraph (boundary 0) or after its sentence `boundary - 1`.
    private struct Point: Hashable {
        let paragraph: Int
        let boundary: Int
    }

    private struct Cue {
        let text: String
        let key: String
        let paragraph: Int
        let boundary: Int
        /// The words of the sentences on either side, nil at the edges of a paragraph.
        let previous: Set<String>?
        let next: Set<String>?
        /// Where it is, as the share of the paragraph's words before it, and of the script's.
        let inParagraph: Double
        let inScript: Double
    }

    /// A cue as it is found, before the paragraph it is in is whole.
    private struct Found {
        let text: String
        let paragraph: Int
        let boundary: Int
        let sentence: Int
        let paragraphWords: Int
        let scriptWords: Int
    }

    private struct Paragraph {
        /// The index of its line in the text.
        let line: Int
        let sentences: [String]
        let tokens: [Set<String>]
        /// The words of the paragraph before each boundary.
        let wordsBefore: [Int]
        let words: Int
        let scriptWordsBefore: Int
    }

    private struct Layout {
        let lines: [String]
        let paragraphs: [Paragraph]
        let cues: [Cue]
        let totalWords: Int

        func point(for cue: Cue, inSameParagraph same: Bool) -> Point {
            let searched = same ? [cue.paragraph] : Array(paragraphs.indices)
            if cue.boundary > 0 {
                if let previous = cue.previous, let found = sentence(like: previous, in: searched) {
                    return Point(paragraph: found.paragraph, boundary: found.sentence + 1)
                }
                if let next = cue.next, let found = sentence(like: next, in: searched) {
                    return Point(paragraph: found.paragraph, boundary: found.sentence)
                }
            }
            return same ? point(inParagraph: cue.paragraph, near: cue.inParagraph, leading: cue.boundary == 0)
                : point(near: cue.inScript, leading: cue.boundary == 0)
        }

        /// The sentence of `searched` paragraphs that is most the same as one with `words`: most of the shorter one's words in the other.
        private func sentence(like words: Set<String>, in searched: [Int]) -> (paragraph: Int, sentence: Int)? {
            var best: (paragraph: Int, sentence: Int)?
            var bestScore = 0.6
            for index in searched {
                for (position, tokens) in paragraphs[index].tokens.enumerated() {
                    let shared = words.intersection(tokens).count
                    guard shared >= 2 else { continue }
                    let score = Double(shared) / Double(min(words.count, tokens.count))
                    if score > bestScore || (best == nil && score == bestScore) {
                        bestScore = score
                        best = (index, position)
                    }
                }
            }
            return best
        }

        private func point(inParagraph index: Int, near share: Double, leading: Bool) -> Point {
            let paragraph = paragraphs[index]
            guard !leading, !paragraph.sentences.isEmpty else { return Point(paragraph: index, boundary: 0) }
            let best = (1...paragraph.sentences.count).min { lhs, rhs in
                abs(self.share(paragraph.wordsBefore[lhs], of: paragraph.words) - share)
                    < abs(self.share(paragraph.wordsBefore[rhs], of: paragraph.words) - share)
            } ?? paragraph.sentences.count
            return Point(paragraph: index, boundary: best)
        }

        private func point(near share: Double, leading: Bool) -> Point {
            var best = Point(paragraph: 0, boundary: 0)
            var distance = Double.infinity
            for (index, paragraph) in paragraphs.enumerated() {
                for boundary in 0...paragraph.sentences.count {
                    let here = self.share(paragraph.scriptWordsBefore + paragraph.wordsBefore[boundary], of: totalWords)
                    // At the same point, a cue that opened a paragraph opens one again, and one that closed a sentence closes one.
                    let gap = abs(here - share) + ((boundary == 0) == leading ? 0 : 0.000_1)
                    if gap < distance {
                        distance = gap
                        best = Point(paragraph: index, boundary: boundary)
                    }
                }
            }
            return best
        }

        func text(adding additions: [Point: [String]]) -> String {
            var lines = lines
            for (index, paragraph) in paragraphs.enumerated() {
                var line = ""
                if let leading = additions[Point(paragraph: index, boundary: 0)] {
                    line += leading.joined(separator: " ") + " "
                }
                for (position, sentence) in paragraph.sentences.enumerated() {
                    let spaces = sentence.reversed().prefix(while: \.isWhitespace).count
                    line += sentence.dropLast(spaces)
                    if let added = additions[Point(paragraph: index, boundary: position + 1)] {
                        line += " " + added.joined(separator: " ")
                    }
                    line += sentence.suffix(spaces)
                }
                lines[paragraph.line] = line
            }
            return lines.joined(separator: "\n")
        }

        private func share(_ part: Int, of whole: Int) -> Double {
            whole > 0 ? Double(part) / Double(whole) : 0
        }
    }

    private static func layout(of text: String) -> Layout {
        let lines = text.components(separatedBy: "\n")
        var paragraphs: [Paragraph] = []
        var scriptWords = 0
        var found: [Found] = []
        for (lineIndex, raw) in lines.enumerated() {
            let line = raw.trimmingCharacters(in: .whitespaces)
            guard !line.isEmpty else { continue }
            let sentences = ScriptParagraphs.sentences(of: line)
            var wordsBefore = [0]
            var paragraphWords = 0
            for (index, sentence) in sentences.enumerated() {
                // A cue before any word of a paragraph's first sentence opens the paragraph; any other closes the sentence it is in.
                for match in sentence.matches(of: /\[[^\]\n]*\]/) {
                    let opens = index == 0 && ReadTime.wordCount(in: String(sentence[..<match.range.lowerBound])) == 0
                    let wordsThere = opens ? 0 : paragraphWords + ReadTime.wordCount(in: sentence)
                    found.append(Found(
                        text: String(sentence[match.range]), paragraph: paragraphs.count, boundary: opens ? 0 : index + 1, sentence: index,
                        paragraphWords: wordsThere, scriptWords: scriptWords + wordsThere
                    ))
                }
                paragraphWords += ReadTime.wordCount(in: sentence)
                wordsBefore.append(paragraphWords)
            }
            paragraphs.append(Paragraph(
                line: lineIndex, sentences: sentences, tokens: sentences.map(tokens(of:)), wordsBefore: wordsBefore, words: paragraphWords,
                scriptWordsBefore: scriptWords
            ))
            scriptWords += paragraphWords
        }
        let cues = found.map { cue in
            let paragraph = paragraphs[cue.paragraph]
            let opens = cue.boundary == 0
            return Cue(
                text: cue.text, key: key(cue.text), paragraph: cue.paragraph, boundary: cue.boundary,
                previous: opens ? nil : paragraph.tokens[cue.sentence],
                next: !opens && cue.sentence + 1 < paragraph.tokens.count ? paragraph.tokens[cue.sentence + 1] : nil,
                inParagraph: paragraph.words > 0 ? Double(cue.paragraphWords) / Double(paragraph.words) : 0,
                inScript: scriptWords > 0 ? Double(cue.scriptWords) / Double(scriptWords) : 0
            )
        }
        return Layout(lines: lines, paragraphs: paragraphs, cues: cues, totalWords: scriptWords)
    }

    /// A sentence's words, in lower case without punctuation; pairs of characters in a language written without spaces (Japanese, Chinese, Thai).
    private static func tokens(of sentence: String) -> Set<String> {
        let spoken: String = CueParser.stripCues(sentence).lowercased()
        let letters: [Character] = spoken.map { character in character.isLetter || character.isNumber ? character : " " }
        if WordSegmenter.containsUnspacedScript(spoken) {
            let characters = letters.filter { $0 != " " }
            return Set(zip(characters, characters.dropFirst()).map { String([$0, $1]) })
        }
        return Set(String(letters).split(separator: " ").map(String.init))
    }

    // MARK: - Matching

    /// The cues of `source` the result has no copy of: every copy the result has stands for the source's copy nearest it, so of three "[pause]" with one
    /// left, the two that are back are the two it didn't keep.
    private static func unmatched(_ source: [Cue], against result: [Cue]) -> [Cue] {
        var matched = Set<Int>()
        for key in Set(source.map(\.key)) {
            let mine = source.indices.filter { source[$0].key == key }
            let theirs = result.filter { $0.key == key }
            var pairs: [(distance: Double, source: Int, result: Int)] = []
            for index in mine {
                for (other, cue) in theirs.enumerated() {
                    pairs.append((abs(source[index].inScript - cue.inScript), index, other))
                }
            }
            var used = Set<Int>()
            for pair in pairs.sorted(by: { $0.distance < $1.distance }) where !matched.contains(pair.source) && !used.contains(pair.result) {
                matched.insert(pair.source)
                used.insert(pair.result)
            }
        }
        return source.indices.filter { !matched.contains($0) }.map { source[$0] }
    }

    private static func key(_ cue: String) -> String {
        cue.dropFirst().dropLast().lowercased().split(whereSeparator: \.isWhitespace).joined(separator: " ")
    }
}
