//
//  FitTopUp.swift
//  Cue Studio
//

import Foundation

/// The last step of "Fit to time" when a lengthening stops short of the range: instead of another rewrite of the whole, which takes back part of what the
/// last one added, the model writes only what to add (one more point, an example, a moment from the speaker's day) and it goes in before the closing
/// line, with the creator's words as they were. Measured on the iPhone (ScriptToolsQualityDeviceTests, 01/11/2026): Private Cloud Compute lengthening a
/// script to 75–105 s stopped at 61 to 75 s in 6 of 23, after three rounds over the whole.
nonisolated enum FitTopUp {
    /// The words to ask for: up to the high part of where a lengthening aims (`RewriteRunner`), since the model writes less than it is asked to.
    static func wordsToAsk(from words: Int, toward aim: ClosedRange<Int>) -> Int {
        max(0, aim.upperBound - words)
    }

    /// `addition` as it may go into `text`, or nil: without cues of its own, with no number the script doesn't have, about as long as asked, and not
    /// the script's own sentences again.
    static func accepted(_ addition: String, into text: String, asked: Int) -> String? {
        let cleaned: String
        switch reading(of: addition, against: text) {
        case .addition(let written): cleaned = clean(written)
        case .scriptAgain(let added?): cleaned = clean(added)
        case .scriptAgain(nil): return nil
        }
        let words = ReadTime.wordCount(in: cleaned)
        guard words >= max(3, asked / 4), words <= asked * 2 + 10 else { return nil }
        guard numbers(in: cleaned).isSubset(of: numbers(in: text)) else { return nil }
        let added = cleaned.lowercased()
        let repeats = ScriptParagraphs.sentences(of: CueParser.stripCues(text).replacing(/\s+/, with: " ")).contains { sentence in
            let sentence = sentence.trimmingCharacters(in: .whitespaces).lowercased()
            return ReadTime.wordCount(in: sentence) >= 5 && added.contains(sentence)
        }
        return repeats ? nil : cleaned
    }

    /// `text` with `addition` before its closing: a paragraph of its own before the last paragraph, or, in a script of one paragraph, before its last
    /// sentence (where a call to action is).
    static func inserting(_ addition: String, into text: String) -> String {
        let script = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if let lastBreak = script.range(of: "\n", options: .backwards) {
            var start = lastBreak.lowerBound
            while start > script.startIndex, script[script.index(before: start)].isNewline {
                start = script.index(before: start)
            }
            let gap = String(script[start..<lastBreak.upperBound])
            return String(script[..<start]) + gap + addition + gap + String(script[lastBreak.upperBound...])
        }
        let spacer = script.contains(" ") ? " " : ""
        let sentences = ScriptParagraphs.sentences(of: script)
        guard sentences.count > 1, let last = sentences.last else { return script + spacer + addition }
        let at = script.index(script.endIndex, offsetBy: -last.count, limitedBy: script.startIndex) ?? script.startIndex
        let head = String(script[..<at])
        let joiner = head.last?.isWhitespace == true ? "" : spacer
        return head + joiner + addition + spacer + String(script[at...]).trimmingCharacters(in: .whitespaces)
    }

    /// What the answer is: the addition alone, as asked, or the script written again with the addition in it, which Private Cloud Compute gave
    /// 4 times in 4 (ScriptToolsQualityDeviceTests, 01/11/2026). Then the addition is the sentences the script doesn't have, when they are one run;
    /// new sentences here and there mean the creator's were changed, and nothing is taken.
    private enum Reading {
        case addition(String)
        case scriptAgain(added: String?)
    }

    private static func reading(of answer: String, against text: String) -> Reading {
        let script = key(text)
        let sentences = answer.split(separator: "\n").flatMap { ScriptParagraphs.sentences(of: String($0)) }.filter { !key($0).isEmpty }
        let isOld = sentences.map { script.contains(key($0)) }
        let old = isOld.filter { $0 }.count
        guard old >= 2, old * 2 >= sentences.count else { return .addition(answer) }
        let new = isOld.indices.filter { !isOld[$0] }
        guard let first = new.first, let last = new.last, new.count == last - first + 1 else { return .scriptAgain(added: nil) }
        return .scriptAgain(added: sentences[first...last].joined())
    }

    /// Letters and digits only, in lower case and one space apart: a sentence matches the script's whatever the model did to its dashes and cues.
    private static func key(_ text: String) -> String {
        let letters = CueParser.stripCues(text).lowercased().map { $0.isLetter || $0.isNumber ? $0 : " " }
        return String(letters).split(separator: " ").joined(separator: " ")
    }

    private static func clean(_ text: String) -> String {
        RewriteOutcome.withoutInventedCues(text, comparedTo: "")
            .replacing(/[ \t]{2,}/, with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func numbers(in text: String) -> Set<String> {
        Set(text.matches(of: /\d+(?:[.,]\d+)?/).map { String($0.output) })
    }
}
