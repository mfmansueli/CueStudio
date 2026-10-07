//
//  ExcerptSelector.swift
//  Cue Studio
//

import Foundation

/// Chooses the few sentences of the creator's writing worth keeping: windows of two or three sentences that sound like the rest of what they
/// wrote, spread over how they open, go on and close, from different texts, without links, handles or numbers that could be somebody's.
nonisolated enum ExcerptSelector {
    private struct Candidate {
        let text: String
        let role: VoiceExcerpt.Role
        let piece: Int
        let words: Set<String>
        let score: Double
    }

    /// At most this many excerpts come from one text.
    static let perPiece = 2

    static func excerpts(
        from pieces: [WritingPiece], language: String?, fingerprint: VoiceFingerprint?, phrases: [String], limit: Int = VoiceExcerpt.limit
    ) -> [VoiceExcerpt] {
        var candidates: [Candidate] = []
        for (index, piece) in pieces.enumerated() {
            candidates += windows(of: piece, index: index, language: language, fingerprint: fingerprint, phrases: phrases)
        }
        guard !candidates.isEmpty else { return [] }
        var chosen: [Candidate] = []
        var used: [Int: Int] = [:]
        var roles = VoiceExcerpt.Role.allCases
        // One role after another, so how they open, go on and close are all there; the best of each that is unlike what is already kept.
        while chosen.count < limit, !roles.isEmpty {
            var progressed = false
            for role in roles {
                guard chosen.count < limit else { break }
                let pool = candidates.filter { candidate in
                    candidate.role == role && used[candidate.piece, default: 0] < perPiece && !chosen.contains { $0.text == candidate.text }
                }
                let best = pool.max { adjusted($0, against: chosen) < adjusted($1, against: chosen) }
                guard let best, adjusted(best, against: chosen) > 0 else {
                    roles.removeAll { $0 == role }
                    continue
                }
                chosen.append(best)
                used[best.piece, default: 0] += 1
                progressed = true
            }
            if !progressed { break }
        }
        return chosen.map { VoiceExcerpt(text: $0.text, language: language, role: $0.role, source: pieces[$0.piece].source) }
    }

    /// The score less how much it repeats what is already chosen.
    private static func adjusted(_ candidate: Candidate, against chosen: [Candidate]) -> Double {
        let overlap = chosen.map { jaccard(candidate.words, $0.words) }.max() ?? 0
        return candidate.score - 0.8 * overlap
    }

    private static func jaccard(_ lhs: Set<String>, _ rhs: Set<String>) -> Double {
        guard !lhs.isEmpty, !rhs.isEmpty else { return 0 }
        return Double(lhs.intersection(rhs).count) / Double(lhs.union(rhs).count)
    }

    // MARK: - Windows

    private static func windows(
        of piece: WritingPiece, index: Int, language: String?, fingerprint: VoiceFingerprint?, phrases: [String]
    ) -> [Candidate] {
        let sentences = WritingText.sentences(in: piece.text, language: language)
        guard !sentences.isEmpty else { return [] }
        var found: [(text: String, role: VoiceExcerpt.Role)] = []
        // How they open: from the first sentence. How they go on: from the middle. How they close: back from the last.
        if let text = window(in: sentences, from: 0) { found.append((text, .opening)) }
        if sentences.count >= 4, let text = window(in: sentences, from: max(1, sentences.count / 2 - 1)) { found.append((text, .body)) }
        if sentences.count >= 3, let text = closingWindow(in: sentences) { found.append((text, .closing)) }
        return found.filter { isSafe($0.text) }.map { window in
            Candidate(
                text: window.text, role: window.role, piece: index, words: wordSet(window.text, language),
                score: score(window.text, language: language, fingerprint: fingerprint, phrases: phrases)
            )
        }
    }

    /// Whole sentences from `start`, up to the room an excerpt has; nil when they say too little.
    private static func window(in sentences: [String], from start: Int) -> String? {
        var text = ""
        for sentence in sentences[start...] {
            let next = text.isEmpty ? sentence : text + " " + sentence
            guard next.count <= VoiceExcerpt.maximumCharacters else { break }
            text = next
            if text.count >= 160 { break }
        }
        return ReadTime.wordCount(in: text) >= VoiceExcerpt.minimumWords ? text : nil
    }

    /// Whole sentences ending at the last one, up to the room an excerpt has.
    private static func closingWindow(in sentences: [String]) -> String? {
        var text = ""
        for sentence in sentences.reversed() {
            let next = text.isEmpty ? sentence : sentence + " " + text
            guard next.count <= VoiceExcerpt.maximumCharacters else { break }
            text = next
            if text.count >= 160 { break }
        }
        return ReadTime.wordCount(in: text) >= VoiceExcerpt.minimumWords ? text : nil
    }

    /// Nothing that can identify anyone or that the model won't learn from.
    private static func isSafe(_ text: String) -> Bool {
        if VoiceTextValidator.isBlocked(text) { return false }
        if text.range(of: #"\d{5,}"#, options: .regularExpression) != nil { return false }
        return !text.contains("@") && !text.lowercased().contains("http")
    }

    private static func wordSet(_ text: String, _ language: String?) -> Set<String> {
        let lexicon = WritingLexicon.lexicon(for: language)
        return Set(WritingText.words(in: text, language: language).map(\.key).filter { $0.count > 2 && !(lexicon?.filler.contains($0) ?? false) })
    }

    /// How well the window stands for the creator: sentences as long as theirs, questions as often, and their own phrases in it.
    private static func score(_ text: String, language: String?, fingerprint: VoiceFingerprint?, phrases: [String]) -> Double {
        var value = 1.0
        let sentences = WritingText.sentences(in: text, language: language)
        if let fingerprint, !sentences.isEmpty {
            let mine = Double(ReadTime.wordCount(in: text)) / Double(sentences.count)
            let theirs = max(1, fingerprint.wordsPerSentence)
            value -= min(1, abs(mine - theirs) / max(mine, theirs))
            let questions = Double(sentences.filter(WritingText.isQuestion).count) / Double(sentences.count)
            value -= 0.5 * abs(questions - fingerprint.questionShare)
        }
        let folded = VoiceTextValidator.key(text)
        if phrases.contains(where: { folded.contains(VoiceTextValidator.key($0)) }) { value += 0.25 }
        // Never so low that a creator whose sentences all differ from their average ends up with no excerpt at all.
        return max(0.1, value)
    }
}
