//
//  RewriteChunker.swift
//  Cue Studio
//

import Foundation

/// Cuts a script into the parts the model can answer for in full. Measured on an iPhone 15 Pro: handed 374 words and asked only to fix the grammar, the
/// model answered with 188, and with 188 again for 1309: a long script was cut to a third and the tool said "Grammar fixed". A part of about 150 words
/// comes back whole, so a script of any length is edited a part at a time, each checked on its own (`RewriteOutcome`).
nonisolated enum RewriteChunker {
    /// What one part costs the model at most, in characters of English (`PromptCost`): about 150 English words, so that the part and its answer are
    /// a small share of the 4096 tokens, whatever the language.
    static let partUnits = 800
    /// The smallest part worth a request of its own, in the same measure: a short closing paragraph joins the one before it.
    private static let smallestUnits = 160

    /// The parts of `text` for `tool`, in order. `expansion` is how many times longer the result should be than the script is (1 when it isn't
    /// asked to grow): the model grows a part by about three times and no more, so a script to be made five times longer is cut in smaller parts.
    /// A script to be cut to less than half goes whole, up to four parts' worth: its answer is short, and only the whole tells what matters most
    /// (measured on the iPhone, run `after`, 01/11/2026: a version for Instagram Stories, 15–30 s, asked of three parts of Ultra AI's 350 words, came
    /// back at 52 to 92 s, each part cut to its share of what it says).
    static func chunks(of text: String, for tool: ScriptTool, expansion: Double = 1) -> [RewriteChunk] {
        let paragraphs = paragraphs(of: text)
        guard !paragraphs.isEmpty else { return [] }
        if tool == .strongerCTA { return closingChunks(paragraphs) }
        if expansion < 0.5, PromptCost.units(of: text) <= partUnits * 4 {
            return [RewriteChunk(text: joining(paragraphs).text)]
        }
        let room = expansion > 3 ? max(smallestUnits, Int(Double(partUnits) * 3 / expansion)) : partUnits
        return group(paragraphs, within: room).map { RewriteChunk(text: $0.text, gap: $0.gap) }
    }

    /// The parts put back together, each followed by what followed it in the script (`gaps`, one per part: a blank line, a line break, a space
    /// between the sentences of a paragraph cut in two), so a tool never changes how the script is laid out. A part that came back empty is left out.
    static func joined(_ parts: [String], gaps: [String]) -> String {
        var text = ""
        var gap = ""
        for (index, part) in parts.enumerated() {
            let part = part.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !part.isEmpty else { continue }
            text += (text.isEmpty ? "" : gap) + part
            gap = index < gaps.count && !gaps[index].isEmpty ? gaps[index] : "\n\n"
        }
        return text
    }

    // MARK: - Cutting

    /// A paragraph or a piece of one, and what follows it in the script ("\n\n", "\n", " "; "" at the end).
    private struct Piece {
        var text: String
        var gap: String
    }

    /// The paragraphs, each with the line breaks after it: one, or a blank line (however many there were).
    private static func paragraphs(of text: String) -> [Piece] {
        var pieces: [Piece] = []
        var breaks = 0
        for line in text.split(separator: "\n", omittingEmptySubsequences: false) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty {
                breaks += 1
                continue
            }
            if !pieces.isEmpty { pieces[pieces.count - 1].gap = breaks > 0 ? "\n\n" : "\n" }
            pieces.append(Piece(text: trimmed, gap: ""))
            breaks = 0
        }
        return pieces
    }

    /// Pieces put together with what was between them; the whole is followed by what followed the last.
    private static func joining(_ pieces: some BidirectionalCollection<Piece>) -> Piece {
        var text = ""
        for (index, piece) in pieces.enumerated() {
            text += piece.text + (index < pieces.count - 1 ? piece.gap : "")
        }
        return Piece(text: text, gap: pieces.last?.gap ?? "")
    }

    /// "Stronger CTA" rewrites the closing and nothing else: the paragraphs before it go through as they are, and the last one is asked with the one
    /// before it beside it to read. A script written in one paragraph closes with its last two sentences: the rest of it isn't the call to action.
    private static func closingChunks(_ paragraphs: [Piece]) -> [RewriteChunk] {
        if paragraphs.count == 1 {
            let sentences = WritingText.sentences(in: paragraphs[0].text)
            guard sentences.count > 2 else { return [RewriteChunk(text: paragraphs[0].text)] }
            let split = sentences.count - 2
            return [
                RewriteChunk(text: sentences[..<split].joined(separator: " "), isRewritten: false, gap: " "),
                RewriteChunk(text: sentences[split...].joined(separator: " "), leadIn: sentences[split - 1]),
            ]
        }
        let before = joining(paragraphs.dropLast())
        let leadIn = paragraphs[paragraphs.count - 2].text
        return [
            RewriteChunk(text: before.text, isRewritten: false, gap: before.gap),
            RewriteChunk(text: paragraphs[paragraphs.count - 1].text, leadIn: leadIn),
        ]
    }

    /// Paragraphs gathered until the next would not fit; one that is too long by itself is cut at its sentences.
    private static func group(_ paragraphs: [Piece], within room: Int) -> [Piece] {
        var groups: [Piece] = []
        var current: [Piece] = []
        var used = 0
        func flush() {
            if !current.isEmpty { groups.append(joining(current)) }
            current = []
            used = 0
        }
        for paragraph in paragraphs.flatMap({ pieces(of: $0, within: room) }) {
            let cost = PromptCost.units(of: paragraph.text)
            if used + cost > room { flush() }
            current.append(paragraph)
            used += cost
        }
        flush()
        return merged(groups, within: room)
    }

    /// The paragraph itself, or its sentences gathered into pieces that fit when it doesn't (a space between them, as between sentences).
    private static func pieces(of paragraph: Piece, within room: Int) -> [Piece] {
        guard PromptCost.units(of: paragraph.text) > room else { return [paragraph] }
        var found: [Piece] = []
        var current = ""
        for sentence in WritingText.sentences(in: paragraph.text) {
            let next = current.isEmpty ? sentence : current + " " + sentence
            if PromptCost.units(of: next) > room, !current.isEmpty {
                found.append(Piece(text: current, gap: " "))
                current = sentence
            } else {
                current = next
            }
        }
        if !current.isEmpty { found.append(Piece(text: current, gap: " ")) }
        if !found.isEmpty { found[found.count - 1].gap = paragraph.gap }
        return found
    }

    /// A last part too small to ask for by itself joins the one before it, when that has room.
    private static func merged(_ groups: [Piece], within room: Int) -> [Piece] {
        guard groups.count > 1, let last = groups.last, PromptCost.units(of: last.text) < smallestUnits else { return groups }
        let joined = joining(groups.suffix(2))
        guard PromptCost.units(of: joined.text) <= room + smallestUnits else { return groups }
        return Array(groups.dropLast(2)) + [joined]
    }
}
