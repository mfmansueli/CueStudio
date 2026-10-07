//
//  PhraseMiner.swift
//  Cue Studio
//

import Foundation

/// Finds the phrases a creator really says: the same few words in texts that have nothing else in common ("real talk", "see you tomorrow").
/// A phrase counts when it comes back in several separate texts, is not only filler words, and is told apart from a longer phrase it is part of.
nonisolated enum PhraseMiner {
    /// Fewer texts than this and a repeat is a coincidence.
    static let minimumPieces = 3
    private static let sizes = 2...5

    private struct Seen {
        /// How it was written, and how many texts wrote it that way.
        var surfaces: [String: Int]
        var pieces = 0
        var atEdge = 0
        /// In how many texts it starts a sentence, and in how many it ends one.
        var starts = 0
        var ends = 0
        var size: Int

        /// The way most texts wrote it; capitalised when that ties ("Follow for part two" over "follow for part two").
        var surface: String {
            surfaces.max { lhs, rhs in
                if lhs.value != rhs.value { return lhs.value < rhs.value }
                let lhsUpper = lhs.key.first?.isUppercase ?? false, rhsUpper = rhs.key.first?.isUppercase ?? false
                return lhsUpper != rhsUpper ? !lhsUpper : lhs.key > rhs.key
            }?.key ?? ""
        }
    }

    /// The phrases (as written, at most `limit`), best first. `pieces` are texts in `language`.
    static func phrases(in pieces: [WritingPiece], language: String?, limit: Int = VoiceLimits.phrases) -> [String] {
        guard pieces.count >= minimumPieces else { return [] }
        let lexicon = WritingLexicon.lexicon(for: language)
        var seen: [String: Seen] = [:]
        for piece in pieces {
            for (key, found) in phrases(of: piece, language: language) {
                var entry = seen[key] ?? Seen(surfaces: [:], size: found.size)
                entry.surfaces[found.surface, default: 0] += 1
                entry.pieces += 1
                if found.atEdge { entry.atEdge += 1 }
                if found.starts { entry.starts += 1 }
                if found.ends { entry.ends += 1 }
                seen[key] = entry
            }
        }
        let needed = max(2, Int((Double(pieces.count) * 0.15).rounded(.up)))
        let candidates = seen.filter { key, entry in
            // Two words come back by chance: they need one more text than longer phrases do.
            entry.pieces >= (entry.size == 2 ? needed + 1 : needed) && isWorthKeeping(key, entry: entry, lexicon: lexicon)
                && (4...VoiceLimits.phraseLength).contains(entry.surface.count)
        }
        // A phrase inside a longer one that comes back as often is the longer one's piece.
        let maximal = candidates.filter { key, entry in
            !candidates.contains { other, otherEntry in
                other != key && otherEntry.pieces >= entry.pieces && " \(other) ".contains(" \(key) ")
            }
        }
        let ranked = maximal.sorted { lhs, rhs in
            let left = score(lhs.value), right = score(rhs.value)
            return left != right ? left > right : lhs.key < rhs.key
        }
        var kept: [String] = []
        for (_, entry) in ranked {
            let text = entry.surface.trimmingCharacters(in: CharacterSet(charactersIn: ".,;:!?…\"“”()¿¡ "))
            guard text.count >= 4, !VoiceTextValidator.isBlocked(text) else { continue }
            kept.append(text)
            if kept.count == limit { break }
        }
        return kept
    }

    private static func score(_ entry: Seen) -> Double {
        Double(entry.pieces) * (1 + 0.3 * Double(entry.size - 2)) + 1.5 * Double(entry.atEdge)
    }

    /// The word groups of one text, each once, with how it was written and whether it opens or closes the text.
    private struct Found {
        let surface: String
        let size: Int
        let atEdge: Bool
        let starts: Bool
        let ends: Bool
    }

    private static func phrases(of piece: WritingPiece, language: String?) -> [String: Found] {
        var found: [String: Found] = [:]
        let sentences = WritingText.sentences(in: piece.text, language: language)
        for (index, sentence) in sentences.enumerated() {
            let words = WritingText.words(in: sentence, language: language)
            for size in sizes where words.count >= size {
                for start in 0...(words.count - size) {
                    let group = words[start..<(start + size)]
                    let key = group.map(\.key).joined(separator: " ")
                    guard found[key] == nil else { continue }
                    let surface = String(sentence[group.first!.range.lowerBound..<group.last!.range.upperBound])
                    let atEdge = (index == 0 && start == 0) || (index == sentences.count - 1 && start + size == words.count)
                    found[key] = Found(surface: surface, size: size, atEdge: atEdge, starts: start == 0, ends: start + size == words.count)
                }
            }
        }
        return found
    }

    /// Not only filler, no numbers, not a string of tiny words, not cut off ("once a" of "once a week", "and tell me how"), and not an ask the
    /// creator makes in the same two words every time ("save this" is an ending, and has its own answer).
    private static func isWorthKeeping(_ key: String, entry: Seen, lexicon: WritingLexicon?) -> Bool {
        let words = key.split(separator: " ").map(String.init)
        if words.contains(where: { $0.contains(where: \.isNumber) }) { return false }
        // Said as a unit: it begins or ends a sentence in at least half of the texts. What is always in the middle of one is a piece of it.
        if Double(entry.starts + entry.ends) < 0.5 * Double(entry.pieces) { return false }
        if let lexicon {
            let pieces = Double(entry.pieces)
            // A phrase that begins with a filler word ("and tell me") or ends with one ("tell me how") is a piece of a sentence, unless it is
            // the whole of the sentence's beginning or end every time.
            if let first = words.first, lexicon.filler.contains(first), !lexicon.singular.contains(first), !lexicon.plural.contains(first),
               Double(entry.starts) < 0.75 * pieces { return false }
            if let last = words.last, lexicon.filler.contains(last), Double(entry.ends) < 0.5 * pieces { return false }
            let asks = lexicon.save + lexicon.follow + lexicon.comment + lexicon.linkInBio + lexicon.tryIt
            if words.count <= 2, asks.contains(where: { key.contains($0.trimmingCharacters(in: .whitespaces)) }) { return false }
        }
        let content = words.filter { word in
            if let lexicon { return !lexicon.filler.contains(word) && word.count > 2 }
            return word.count > 3
        }
        return !content.isEmpty
    }
}
