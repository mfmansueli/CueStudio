//
//  WritingCleaner.swift
//  Cue Studio
//

import Foundation

/// Turns what the creator pasted or opened into separate, clean texts: one script, note or caption each, without links, handles, hashtags,
/// contact data or stage cues, which say nothing about how they write (and must never travel in an example).
nonisolated enum WritingCleaner {
    /// A text with fewer words says nothing about how someone writes.
    static let minimumWords = 12
    /// A text is read up to this many words.
    static let maximumWords = 1_200
    /// At most this many texts, and this many characters of all of them, are read at once.
    static let maximumPieces = 60
    static let maximumCharacters = 80_000

    /// Words that name a part of a script ("Hook:", "CTA:"): the label goes, what follows stays.
    private static let labels: Set<String> = [
        "hook", "intro", "cta", "outro", "body", "script", "title", "scene", "part", "step", "promise", "payoff", "gancho", "título", "titulo",
        "corpo", "cena", "parte", "passo", "roteiro", "texto", "caption", "legenda",
    ]

    /// The texts in `raw`, in order. Lines of `---` (or `***`, `===`) separate texts; without them a short paste is one text and a long one
    /// is cut at blank lines.
    static func pieces(from raw: String, source: String? = nil) -> [WritingPiece] {
        let bounded = String(normalized(raw).prefix(maximumCharacters))
        var seen = Set<String>()
        var pieces: [WritingPiece] = []
        for block in blocks(of: bounded) {
            let text = cleaned(block)
            guard acceptable(text) else { continue }
            let key = VoiceTextValidator.key(String(text.prefix(120)))
            guard seen.insert(key).inserted else { continue }
            pieces.append(WritingPiece(text: capped(text), source: source))
            if pieces.count == maximumPieces { break }
        }
        return pieces
    }

    // MARK: - Splitting

    private static func normalized(_ raw: String) -> String {
        raw.replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .replacingOccurrences(of: "\u{2028}", with: "\n")
            .replacingOccurrences(of: "\u{FEFF}", with: "")
    }

    private static func isSeparator(_ line: String) -> Bool {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard trimmed.count >= 3 else { return false }
        return trimmed.range(of: #"^([-–—_*=~#]\s*){3,}$"#, options: .regularExpression) != nil
    }

    private static func blocks(of text: String) -> [String] {
        let lines = text.components(separatedBy: "\n")
        if lines.contains(where: isSeparator) {
            var blocks: [String] = []
            var current: [String] = []
            for line in lines {
                if isSeparator(line) {
                    blocks.append(current.joined(separator: "\n"))
                    current = []
                } else {
                    current.append(line)
                }
            }
            blocks.append(current.joined(separator: "\n"))
            return blocks
        }
        let paragraphs = text.components(separatedBy: "\n\n").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        let sizes = paragraphs.map { ReadTime.wordCount(in: $0) }.sorted()
        // Several paragraphs that are each about a script long are several scripts.
        if paragraphs.count >= 3, sizes[sizes.count / 2] >= 35 { return paragraphs }
        if ReadTime.wordCount(in: text) <= 400 || paragraphs.count < 3 { return [text] }
        // A long paste of short paragraphs, with no separators: grouped to about a script each.
        var blocks: [String] = []
        var current = ""
        for paragraph in paragraphs {
            current += (current.isEmpty ? "" : "\n\n") + paragraph
            if ReadTime.wordCount(in: current) >= 60 {
                blocks.append(current)
                current = ""
            }
        }
        if !current.isEmpty { blocks.append(current) }
        return blocks
    }

    // MARK: - Cleaning

    /// `block` without markdown, labels, cues, links, handles, hashtags and contact data, as running text.
    static func cleaned(_ block: String) -> String {
        let lines = block.components(separatedBy: "\n").map(cleanedLine)
        let nonEmpty = lines.filter { !$0.isEmpty }
        // Scripts are often one sentence a line, with no full stops: each line is then a sentence.
        let unpunctuated = nonEmpty.filter { line in line.last.map { !".!?…。！？؟".contains($0) } ?? false }.count
        let oneSentencePerLine = nonEmpty.count >= 3 && Double(unpunctuated) / Double(nonEmpty.count) > 0.6
        var paragraphs: [String] = []
        var current: [String] = []
        for line in lines {
            if line.isEmpty {
                if !current.isEmpty { paragraphs.append(join(current, asSentences: oneSentencePerLine)) }
                current = []
            } else {
                current.append(line)
            }
        }
        if !current.isEmpty { paragraphs.append(join(current, asSentences: oneSentencePerLine)) }
        return paragraphs.joined(separator: "\n\n")
    }

    private static func join(_ lines: [String], asSentences: Bool) -> String {
        guard asSentences else { return lines.joined(separator: " ") }
        return lines.map { line in line.last.map { ".!?…。！？؟".contains($0) } ?? true ? line : line + "." }.joined(separator: " ")
    }

    private static func cleanedLine(_ raw: String) -> String {
        var line = raw.trimmingCharacters(in: .whitespaces)
        // Markdown and list markers.
        line = line.replacingOccurrences(of: #"^(#{1,6}\s+|>\s*|[-*+•]\s+|\d{1,2}[.)]\s+)"#, with: "", options: .regularExpression)
        line = line.replacingOccurrences(of: #"[*_`~]{1,3}"#, with: "", options: .regularExpression)
        // Stage cues and tags in brackets, links, emails, phone numbers, handles and hashtags.
        line = line.replacingOccurrences(of: #"\[[^\]]*\]|<[^>]*>"#, with: "", options: .regularExpression)
        line = line.replacingOccurrences(of: #"https?://\S+|www\.\S+"#, with: "", options: [.regularExpression, .caseInsensitive])
        line = line.replacingOccurrences(of: #"[\w.+-]+@[\w-]+\.[\w.-]+"#, with: "", options: .regularExpression)
        line = line.replacingOccurrences(of: #"\+?\d[\d\s().-]{7,}\d"#, with: "", options: .regularExpression)
        line = line.replacingOccurrences(of: #"(^|\s)[#@][\p{L}\p{N}_.]+"#, with: " ", options: .regularExpression)
        // "00:12" time stamps at the start of a line.
        line = line.replacingOccurrences(of: #"^\(?\d{1,2}:\d{2}(:\d{2})?\)?\s*[-–—]?\s*"#, with: "", options: .regularExpression)
        // "Hook:" and its kind: the label goes.
        if let colon = line.firstIndex(of: ":"), line.distance(from: line.startIndex, to: colon) <= 14 {
            let label = line[..<colon].lowercased().trimmingCharacters(in: CharacterSet.decimalDigits.union(.whitespaces))
            if labels.contains(label) { line = String(line[line.index(after: colon)...]) }
        }
        line = line.replacingOccurrences(of: #"\s{2,}"#, with: " ", options: .regularExpression)
        return line.trimmingCharacters(in: .whitespaces)
    }

    // MARK: - What is kept

    private static func acceptable(_ text: String) -> Bool {
        guard ReadTime.wordCount(in: text) >= minimumWords else { return false }
        let letters = text.filter(\.isLetter).count
        return Double(letters) / Double(max(1, text.count)) >= 0.5
    }

    /// `text` cut at `maximumWords` words, at a sentence end when there is one.
    private static func capped(_ text: String) -> String {
        guard ReadTime.wordCount(in: text) > maximumWords else { return text }
        var kept = ""
        for sentence in WritingText.sentences(in: text) {
            guard ReadTime.wordCount(in: kept + " " + sentence) <= maximumWords else { break }
            kept += (kept.isEmpty ? "" : " ") + sentence
        }
        return kept.isEmpty ? String(text.prefix(maximumWords * 6)) : kept
    }
}
