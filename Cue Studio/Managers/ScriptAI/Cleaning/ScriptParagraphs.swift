//
//  ScriptParagraphs.swift
//  Cue Studio
//

import Foundation
import NaturalLanguage

/// What the AI wrote, in paragraphs a creator takes in at a glance: one blank line between paragraphs, and a paragraph longer than `longest` words
/// cut at its sentences into paragraphs of about `target` words (the owner's call, 29/10/2026: a script came "muito em blocão"). Paragraphs the
/// model already kept short stay as they are, and no word changes. It is also what keeps the arriving words drawable: each paragraph arrives as one
/// piece (`ArrivingLines`), and one block past about 1:30 grows too tall to draw with its blur and glow, so it vanished until the editor came back.
/// Only for what a model wrote, never for the creator's own text.
nonisolated enum ScriptParagraphs {
    /// Words past which a paragraph is cut.
    static let longest = 70
    /// Words a cut paragraph aims for: a paragraph closes once it has this many.
    static let target = 45
    /// A paragraph left with fewer words after the cuts joins the one before it.
    static let shortest = 15

    static func arranged(_ text: String) -> String {
        text.replacingOccurrences(of: "\r\n", with: "\n")
            .components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .flatMap { ReadTime.wordCount(in: $0) > longest ? cut($0) : [$0] }
            .joined(separator: "\n\n")
    }

    /// A long paragraph in parts of about `target` words, cut only where a sentence ends.
    private static func cut(_ paragraph: String) -> [String] {
        var parts: [String] = []
        var current = ""
        for sentence in sentences(of: paragraph) {
            if !current.isEmpty, ReadTime.wordCount(in: current + sentence) > longest {
                parts.append(current)
                current = ""
            }
            current += sentence
            if ReadTime.wordCount(in: current) >= target {
                parts.append(current)
                current = ""
            }
        }
        if !current.isEmpty {
            if let last = parts.last, ReadTime.wordCount(in: current) < shortest {
                parts[parts.count - 1] = last + current
            } else {
                parts.append(current)
            }
        }
        return parts.map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
    }

    /// The paragraph's sentences, together covering all of it (the space after one stays with it). A cue right after a sentence ("[pause]")
    /// stays with that sentence, where it was written, instead of opening the next paragraph.
    static func sentences(of paragraph: String) -> [String] {
        // The sentences are found with the cues blanked out, one space for each of their characters: a cue in lower case after a full stop
        // ("day. [pause] Then") reads to the tokenizer as the same sentence going on.
        let blanked = paragraph.replacing(/\[[^\]\n]{1,40}\]/) { String(repeating: " ", count: $0.output.count) }
        let tokenizer = NLTokenizer(unit: .sentence)
        tokenizer.string = blanked
        var ends: [String.Index] = []
        tokenizer.enumerateTokens(in: blanked.startIndex..<blanked.endIndex) { range, _ in
            let offset = blanked.distance(from: blanked.startIndex, to: range.upperBound)
            ends.append(paragraph.index(paragraph.startIndex, offsetBy: offset, limitedBy: paragraph.endIndex) ?? paragraph.endIndex)
            return true
        }
        var pieces: [String] = []
        var start = paragraph.startIndex
        for end in ends {
            let cut = pastCues(from: max(end, start), in: paragraph)
            guard cut > start else { continue }
            pieces.append(String(paragraph[start..<cut]))
            start = cut
        }
        if start < paragraph.endIndex {
            if pieces.isEmpty { pieces.append("") }
            pieces[pieces.count - 1] += paragraph[start...]
        }
        return pieces
    }

    /// Where a sentence that ends at `index` really ends: after the cues that follow it and the space after them.
    private static func pastCues(from index: String.Index, in text: String) -> String.Index {
        var position = index
        while true {
            let afterSpace = text[position...].firstIndex { !$0.isWhitespace } ?? text.endIndex
            guard afterSpace < text.endIndex, text[afterSpace] == "[",
                  let close = text[afterSpace...].prefix(42).firstIndex(of: "]"),
                  !text[afterSpace..<close].contains("\n") else { break }
            position = text.index(after: close)
        }
        return text[position...].firstIndex { !$0.isWhitespace } ?? text.endIndex
    }
}
