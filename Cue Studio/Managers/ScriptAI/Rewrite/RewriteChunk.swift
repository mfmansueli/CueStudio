//
//  RewriteChunk.swift
//  Cue Studio
//

import Foundation

/// A part of a script the model works on by itself: the paragraphs that fit in one request.
nonisolated struct RewriteChunk: Equatable, Sendable {
    /// What the part says now.
    let text: String
    /// Whether the model is asked about it at all. A part that is only passed through (what comes before the closing a "Stronger CTA" rewrites)
    /// is carried over as it was.
    let isRewritten: Bool
    /// What comes right before this part, for the model to read and not to touch (a closing paragraph is easier to strengthen next to what leads
    /// up to it).
    let leadIn: String?

    init(text: String, isRewritten: Bool = true, leadIn: String? = nil) {
        self.text = text
        self.isRewritten = isRewritten
        self.leadIn = leadIn
    }

    var words: Int { ReadTime.wordCount(in: text) }
}

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
    static func chunks(of text: String, for tool: ScriptTool, expansion: Double = 1) -> [RewriteChunk] {
        let paragraphs = paragraphs(of: text)
        guard !paragraphs.isEmpty else { return [] }
        if tool == .strongerCTA { return closingChunks(paragraphs) }
        let room = expansion > 3 ? max(smallestUnits, Int(Double(partUnits) * 3 / expansion)) : partUnits
        return group(paragraphs, within: room).map { RewriteChunk(text: $0) }
    }

    /// The parts put back together: a blank line between them.
    static func joined(_ parts: [String]) -> String {
        parts.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }.joined(separator: "\n\n")
    }

    // MARK: - Cutting

    private static func paragraphs(of text: String) -> [String] {
        text.split(whereSeparator: \.isNewline).map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
    }

    /// "Stronger CTA" rewrites the closing paragraph and nothing else: the paragraphs before it go through as they are, and the last one is asked
    /// with the one before it beside it to read.
    private static func closingChunks(_ paragraphs: [String]) -> [RewriteChunk] {
        guard paragraphs.count > 1 else { return [RewriteChunk(text: paragraphs[0])] }
        let before = paragraphs.dropLast().joined(separator: "\n\n")
        let leadIn = paragraphs[paragraphs.count - 2]
        return [RewriteChunk(text: before, isRewritten: false), RewriteChunk(text: paragraphs[paragraphs.count - 1], leadIn: leadIn)]
    }

    /// Paragraphs gathered until the next would not fit; one that is too long by itself is cut at its sentences.
    private static func group(_ paragraphs: [String], within room: Int) -> [String] {
        var groups: [String] = []
        var current: [String] = []
        var used = 0
        func flush() {
            if !current.isEmpty { groups.append(current.joined(separator: "\n\n")) }
            current = []
            used = 0
        }
        for paragraph in paragraphs.flatMap({ pieces(of: $0, within: room) }) {
            let cost = PromptCost.units(of: paragraph)
            if used + cost > room { flush() }
            current.append(paragraph)
            used += cost
        }
        flush()
        return merged(groups, within: room)
    }

    /// The paragraph itself, or its sentences gathered into pieces that fit when it doesn't.
    private static func pieces(of paragraph: String, within room: Int) -> [String] {
        guard PromptCost.units(of: paragraph) > room else { return [paragraph] }
        var found: [String] = []
        var current = ""
        for sentence in WritingText.sentences(in: paragraph) {
            let next = current.isEmpty ? sentence : current + " " + sentence
            if PromptCost.units(of: next) > room, !current.isEmpty {
                found.append(current)
                current = sentence
            } else {
                current = next
            }
        }
        if !current.isEmpty { found.append(current) }
        return found
    }

    /// A last part too small to ask for by itself joins the one before it, when that has room.
    private static func merged(_ groups: [String], within room: Int) -> [String] {
        guard groups.count > 1, let last = groups.last, PromptCost.units(of: last) < smallestUnits else { return groups }
        let joined = groups[groups.count - 2] + "\n\n" + last
        guard PromptCost.units(of: joined) <= room + smallestUnits else { return groups }
        return Array(groups.dropLast(2)) + [joined]
    }
}
