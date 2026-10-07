//
//  ExcerptRetriever.swift
//  Cue Studio
//

import Foundation

/// Picks, for one request, the excerpts of the creator's writing that go to the model as examples of how they write. Research on style
/// imitation says what matters is variety, not a match of subject (examples picked for the topic of the idea made the voice worse), so: the
/// excerpts are in the language of the script, one for how they open and one for how they go on (a third for how they close, when there is
/// room), each the least like the one before, and the subject of the idea only breaks a tie. The same idea always gets the same excerpts.
nonisolated enum ExcerptRetriever {
    /// The script the excerpts are for.
    struct Context: Sendable {
        /// The language the script is written in ("en"); nil takes any.
        var language: String?
        /// What the video is about, in the creator's words.
        var idea: String?
        /// The platform is a professional one (`PlatformRegister`): an excerpt with emoji in it is not an example of how to write there.
        var professional: Bool

        init(language: String? = nil, idea: String? = nil, professional: Bool = false) {
            self.language = language
            self.idea = idea
            self.professional = professional
        }
    }

    static func pick(from library: [VoiceExcerpt], context: Context = Context(), limit: Int = 2) -> [VoiceExcerpt] {
        // Sorted by text, so that equal ranks are settled the same way every time.
        let pool = library.filter { excerpt in
            if context.professional, WritingText.emojiCount(in: excerpt.text) > 0 { return false }
            guard let wanted = context.language, let own = excerpt.language else { return true }
            return VoiceFingerprint.base(own) == VoiceFingerprint.base(wanted)
        }.sorted { $0.text < $1.text }
        guard limit > 0, !pool.isEmpty else { return [] }
        let idea = context.idea.map(contentWords) ?? []
        let order: [VoiceExcerpt.Role] = [.opening, .body, .closing]
        var picked: [VoiceExcerpt] = []
        for role in order.prefix(limit) {
            let candidates = pool.filter { $0.role == role && !picked.contains($0) }
            if let best = candidates.max(by: { rank($0, against: picked, idea: idea) < rank($1, against: picked, idea: idea) }) {
                picked.append(best)
            }
        }
        // A library with no excerpt of a role is filled from what is left, the most different first.
        while picked.count < min(limit, pool.count) {
            let rest = pool.filter { !picked.contains($0) }
            guard let best = rest.max(by: { rank($0, against: picked, idea: idea) < rank($1, against: picked, idea: idea) }) else { break }
            picked.append(best)
        }
        return picked
    }

    /// Higher is better: unlike what is picked, and a little closer to the idea.
    private static func rank(_ excerpt: VoiceExcerpt, against picked: [VoiceExcerpt], idea: Set<String>) -> Double {
        let words = contentWords(excerpt.text)
        let overlap = picked.map { jaccard(words, contentWords($0.text)) }.max() ?? 0
        return -overlap + 0.15 * jaccard(words, idea)
    }

    private static func contentWords(_ text: String) -> Set<String> {
        Set(text.lowercased().split { !$0.isLetter }.map(String.init).filter { $0.count > 3 })
    }

    private static func jaccard(_ lhs: Set<String>, _ rhs: Set<String>) -> Double {
        guard !lhs.isEmpty, !rhs.isEmpty else { return 0 }
        return Double(lhs.intersection(rhs).count) / Double(lhs.union(rhs).count)
    }
}
