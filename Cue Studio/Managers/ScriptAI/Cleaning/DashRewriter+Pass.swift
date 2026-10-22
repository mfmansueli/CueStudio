//
//  DashRewriter+Pass.swift
//  Cue Studio
//

import Foundation

nonisolated extension DashRewriter {
    /// What replaces a range of characters.
    struct Edit {
        var range: Range<Int>
        var replacement: String
    }

    /// One text being rewritten: each dash is turned into an edit, decided inside its own sentence only (what `displayable` relies on), and the
    /// edits are applied from the end.
    struct Pass {
        let characters: [Character]
        let mask: [Bool]
        let sentences: [Range<Int>]
        let punctuation: DashPunctuation
        let rangeTemplate: String

        /// Marks that already join two parts: a dash after one only goes.
        private static let joiners: Set<Character> = [",", ";", ":", "，", "、", "：", "；", "،", "…"]
        private static let commas: Set<Character> = [",", "，", "、", "،"]
        private static let clauseMarks: Set<Character> = [",", ";", ":", "，", "、", "：", "；", "،"]

        func rewritten(_ found: [Dash]) -> String {
            var edits: [Edit] = []
            var paired = Set<Int>()
            for (position, dash) in found.enumerated() where !paired.contains(dash.start) {
                let sentence = sentences.first { $0.contains(dash.start) } ?? 0..<characters.count
                if let edit = minusEdit(for: dash) ?? markEdit(for: dash, in: sentence) ?? rangeEdit(for: dash, in: sentence)
                    ?? endEdit(for: dash, in: sentence) {
                    edits.append(edit)
                    continue
                }
                let partner = found[(position + 1)...].first {
                    sentence.contains($0.start) && !$0.isLineMark && rangeEdit(for: $0, in: sentence) == nil
                }
                if let partner, let pair = pairEdits(dash, partner, in: sentence) {
                    edits += pair
                    paired.insert(partner.start)
                    continue
                }
                edits.append(singleEdit(for: dash, in: sentence))
            }
            var result = characters
            var lowest = Int.max
            for edit in edits.sorted(by: { $0.range.lowerBound > $1.range.lowerBound }) where edit.range.upperBound <= lowest {
                result.replaceSubrange(edit.range, with: Array(edit.replacement))
                lowest = edit.range.lowerBound
            }
            return String(result)
        }

        // MARK: - The cases

        /// "－5℃": the fullwidth hyphen before a number, after a space or nothing, is a minus.
        static func isMinus(_ dash: Dash, in characters: [Character]) -> Bool {
            dash.end - dash.start == 1 && characters[dash.start] == "\u{FF0D}" && (dash.start == 0 || characters[dash.start - 1].isWhitespace)
                && dash.end < characters.count && isDigit(characters[dash.end])
        }

        private func minusEdit(for dash: Dash) -> Edit? {
            Self.isMinus(dash, in: characters) ? Edit(range: dash.start..<dash.end, replacement: "\u{2212}") : nil
        }

        /// A list mark, a dialogue mark, or a dash with nothing before it in its sentence: it goes, with the spaces after it.
        private func markEdit(for dash: Dash, in sentence: Range<Int>) -> Edit? {
            guard dash.isLineMark || text(sentence.lowerBound..<dash.start).isEmpty else { return nil }
            return Edit(range: dash.start..<skipSpaces(from: dash.end, to: sentence.upperBound), replacement: "")
        }

        /// "3–5", "9:00 – 10:30": the language's range ("3 to 5", "3 bis 5", "3〜5").
        private func rangeEdit(for dash: Dash, in sentence: Range<Int>) -> Edit? {
            guard characters[dash.start] != "-" else { return nil }
            let leftEnd = dash.start > sentence.lowerBound && characters[dash.start - 1] == " " ? dash.start - 1 : dash.start
            let rightStart = dash.end < sentence.upperBound && characters[dash.end] == " " ? dash.end + 1 : dash.end
            guard leftEnd > sentence.lowerBound, rightStart < sentence.upperBound,
                  Self.isDigit(characters[leftEnd - 1]), Self.isDigit(characters[rightStart]) else { return nil }
            var start = leftEnd - 1
            while start > sentence.lowerBound, isNumberPart(start - 1, lowest: sentence.lowerBound) { start -= 1 }
            var end = rightStart + 1
            while end < sentence.upperBound, isNumberPart(end, highest: sentence.upperBound) { end += 1 }
            guard !mask[start..<end].contains(true) else { return nil }
            let range = String(format: rangeTemplate, String(characters[start..<leftEnd]), String(characters[rightStart..<end]))
            return Edit(range: start..<end, replacement: range)
        }

        /// A dash that ends its sentence: an unfinished thought ("…"), or nothing before a full stop or after a comma.
        private func endEdit(for dash: Dash, in sentence: Range<Int>) -> Edit? {
            let after = text(dash.end..<sentence.upperBound)
            if let first = after.first, !DashRewriter.terminators.contains(first), !DashRewriter.closers.contains(first) { return nil }
            let start = spacesStart(before: dash.start, from: sentence.lowerBound)
            let end = endOfSpaces(after: dash, in: sentence)
            let ends = after.first.map(DashRewriter.terminators.contains) ?? false
            let joined = start > sentence.lowerBound && Self.joiners.contains(characters[start - 1])
            return Edit(range: start..<end, replacement: ends || joined ? "" : "…")
        }

        /// "A — an aside — B": commas around the aside, or parentheses when it has commas of its own.
        private func pairEdits(_ first: Dash, _ second: Dash, in sentence: Range<Int>) -> [Edit]? {
            let aside = text(first.end..<second.start)
            guard aside.contains(where: { $0.isLetter || $0.isNumber }) else { return nil }
            let parentheses = aside.contains(where: Self.commas.contains)
            let opening = parentheses ? (punctuation.isUnspaced ? "（" : " (") : punctuation.comma
            let openingEdit = joined(opening, replacing: spacesStart(before: first.start, from: sentence.lowerBound)..<skipSpaces(
                from: first.end, to: sentence.upperBound
            ))
            let after = text(second.end..<sentence.upperBound)
            let ends = after.first.map { DashRewriter.terminators.contains($0) || DashRewriter.closers.contains($0) } ?? true
            let closingRange = spacesStart(before: second.start, from: sentence.lowerBound)..<endOfSpaces(after: second, in: sentence)
            let closing: String
            if ends {
                closing = parentheses ? (punctuation.isUnspaced ? "）" : ")") : ""
            } else {
                closing = parentheses ? (punctuation.isUnspaced ? "）" : ") ") : punctuation.comma
            }
            return [openingEdit, ends ? Edit(range: closingRange, replacement: closing) : joined(closing, replacing: closingRange)]
        }

        /// A dash between two parts: a comma before a word that carries the clause on ("until", "até"), a colon after a short head ("Number
        /// one"), a colon before a list, a full stop between two clauses, a comma otherwise.
        private func singleEdit(for dash: Dash, in sentence: Range<Int>) -> Edit {
            let left = text(sentence.lowerBound..<dash.start)
            let right = text(dash.end..<sentence.upperBound)
            let range = spacesStart(before: dash.start, from: sentence.lowerBound)..<skipSpaces(from: dash.end, to: sentence.upperBound)
            if punctuation.isConnector(firstWords: firstWords(of: right)) { return joined(punctuation.comma, replacing: range) }
            if isShortHead(left) { return joined(punctuation.colonInProse ? punctuation.colon : punctuation.comma, replacing: range) }
            if isList(right) { return joined(punctuation.colon, replacing: range) }
            let least = punctuation.isUnspaced ? 4 : 3
            guard punctuation.splitsSentences, size(of: left) >= least, size(of: right) >= least else {
                return joined(punctuation.comma, replacing: range)
            }
            let stop = punctuation.fullStop(inSentenceEndingWith: characters[sentence].last { !$0.isWhitespace })
            guard punctuation.hasCase, let capital = capitalized(at: range.upperBound, in: sentence) else { return joined(stop, replacing: range) }
            return Edit(range: range.lowerBound..<(range.upperBound + 1), replacement: stop + capital)
        }

        // MARK: - Measuring

        /// The text of `range` without stage cues, trimmed.
        private func text(_ range: Range<Int>) -> String {
            String(characters[range]).replacing(/\[[^\]\n]*\]/, with: "").trimmingCharacters(in: .whitespacesAndNewlines)
        }

        /// Words, or letters in a language written without spaces.
        private func size(of text: String) -> Int {
            if punctuation.isUnspaced { return text.filter { $0.isLetter || $0.isNumber }.count }
            return text.split(whereSeparator: \.isWhitespace).filter { $0.contains { $0.isLetter || $0.isNumber } }.count
        }

        /// The last clause before the dash is a head of two words or so ("Number one", "Okay, real talk").
        private func isShortHead(_ left: String) -> Bool {
            let clause = left.split(whereSeparator: Self.clauseMarks.contains).last.map(String.init) ?? left
            let size = size(of: clause)
            return size > 0 && size <= (punctuation.isUnspaced ? 6 : 2)
        }

        /// "light, sound and a hook": two commas, or one and a list word after it.
        private func isList(_ right: String) -> Bool {
            let commas = right.filter(Self.commas.contains).count
            if punctuation.isUnspaced { return commas > 0 }
            guard commas > 0 else { return false }
            let last = right.split(whereSeparator: Self.commas.contains).last.map(String.init) ?? ""
            return commas >= 2 || firstWords(of: last, count: .max).contains(where: punctuation.listWords.contains)
        }

        private func firstWords(of text: String, count: Int = 2) -> [String] {
            if punctuation.isUnspaced { return [text] }
            return text.lowercased().split(whereSeparator: \.isWhitespace).prefix(count)
                .map { $0.trimmingCharacters(in: CharacterSet.punctuationCharacters.subtracting(CharacterSet(charactersIn: "'’"))) }
        }

        /// The letter at `index` in capitals, when a new sentence starts there with a lowercase word ("iPhone" stays).
        private func capitalized(at index: Int, in sentence: Range<Int>) -> String? {
            guard index < sentence.upperBound, !mask[index], characters[index].isLetter, characters[index].isLowercase else { return nil }
            let word = characters[index..<sentence.upperBound].prefix { $0.isLetter }
            guard !word.dropFirst().contains(where: \.isUppercase) else { return nil }
            return String(characters[index]).uppercased(with: Locale(identifier: punctuation.code))
        }

        /// `mark` in place of `range`, without doubling the punctuation already there and without a space before a line break or a full stop.
        private func joined(_ mark: String, replacing range: Range<Int>) -> Edit {
            var mark = mark
            if range.lowerBound > 0, Self.joiners.contains(characters[range.lowerBound - 1]) {
                mark = String(mark.drop { !$0.isWhitespace })
            }
            let next = range.upperBound < characters.count ? characters[range.upperBound] : nil
            if next.map({ $0.isWhitespace || DashRewriter.terminators.contains($0) || DashRewriter.closers.contains($0) || Self.joiners.contains($0) })
                ?? true {
                while mark.last?.isWhitespace == true { mark.removeLast() }
            }
            return Edit(range: range, replacement: mark)
        }

        // MARK: - Characters

        static func isDigit(_ character: Character) -> Bool {
            character.unicodeScalars.count == 1 && character.unicodeScalars.first?.properties.numericType == .decimal
        }

        /// A digit, or a separator between two digits ("1,5", "9:00").
        private func isNumberPart(_ index: Int, lowest: Int = 0, highest: Int = .max) -> Bool {
            if Self.isDigit(characters[index]) { return true }
            guard ".,:".contains(characters[index]) else { return false }
            let before = index - 1 >= lowest && Self.isDigit(characters[index - 1])
            let after = index + 1 < min(highest, characters.count) && Self.isDigit(characters[index + 1])
            return before && after
        }

        private func spacesStart(before index: Int, from lowest: Int) -> Int {
            var start = index
            while start > lowest, characters[start - 1].isWhitespace, !characters[start - 1].isNewline { start -= 1 }
            return start
        }

        private func skipSpaces(from index: Int, to highest: Int) -> Int {
            var end = index
            while end < highest, characters[end].isWhitespace, !characters[end].isNewline { end += 1 }
            return end
        }

        /// After a dash that ends a part: its spaces too when a full stop or a closing quote follows, so none is left before it; otherwise the
        /// spaces stay (before a stage cue, or at the end of a line, where the script's own cleaning trims them).
        private func endOfSpaces(after dash: Dash, in sentence: Range<Int>) -> Int {
            let end = skipSpaces(from: dash.end, to: sentence.upperBound)
            guard end < sentence.upperBound else { return dash.end }
            return DashRewriter.terminators.contains(characters[end]) || DashRewriter.closers.contains(characters[end]) ? end : dash.end
        }
    }
}
