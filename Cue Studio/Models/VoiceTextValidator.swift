//
//  VoiceTextValidator.swift
//  Cue Studio
//

import Foundation

/// What checking a word or phrase the creator typed into My Cue Voice found (04 · F9).
nonisolated enum VoiceTextCheck: Equatable, Sendable {
    /// Fine as it is (trimmed).
    case accepted(String)
    /// Under 2 characters.
    case tooShort
    /// Over 40 characters.
    case tooLong
    /// A word Apple Intelligence won't write: it is not saved.
    case blocked
    /// Already in the list: the existing one gets selected.
    case duplicate(existing: String)
    /// Close to a known option: "Did you mean "{suggestion}"? Use · Keep mine".
    case typo(suggestion: String, original: String)

    /// What to tell the creator; nil when the text is fine.
    var message: String? {
        switch self {
        case .accepted: nil
        case .tooShort: String(localized: "Add a word or two.")
        case .tooLong: String(localized: "Keep it under 40 characters.")
        case .blocked: String(localized: "Apple Intelligence can’t use this word.")
        case .duplicate: String(localized: "Already added.")
        case .typo(let suggestion, _): String(localized: "Did you mean “\(suggestion)”?")
        }
    }
}

/// The rules for free text in My Cue Voice: 2–40 characters, no repeats, no words Apple Intelligence refuses, and a
/// gentle "did you mean" when it looks like a typo of an option the app already offers.
nonisolated enum VoiceTextValidator {
    static let lengths = 2...40
    /// An example is something the creator wrote: a few sentences, not a word.
    static let exampleLengths = 20...600

    static func check(_ raw: String, existing: [String] = [], vocabulary: [String] = []) -> VoiceTextCheck {
        let text = raw.trimmingCharacters(in: .whitespacesAndNewlines).trimmingCharacters(in: CharacterSet(charactersIn: "\"“”"))
        guard text.count >= lengths.lowerBound else { return .tooShort }
        guard text.count <= lengths.upperBound else { return .tooLong }
        if isBlocked(text) { return .blocked }
        if let same = existing.first(where: { key($0) == key(text) }) { return .duplicate(existing: same) }
        if vocabulary.contains(where: { key($0) == key(text) }) { return .accepted(text) }
        if let suggestion = suggestion(for: text, in: vocabulary) { return .typo(suggestion: suggestion, original: text) }
        return .accepted(text)
    }

    /// An example script or caption: long enough to read like the creator, and free of words the model won't learn from.
    static func checkExample(_ raw: String) -> ExampleCheck {
        let text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if text.count < exampleLengths.lowerBound { return .tooShort }
        if isBlocked(text) { return .blocked }
        return .accepted(String(text.prefix(exampleLengths.upperBound)))
    }

    enum ExampleCheck: Equatable, Sendable {
        case accepted(String)
        case tooShort
        case blocked

        var message: String? {
            switch self {
            case .accepted: nil
            case .tooShort: String(localized: "Add 2–4 sentences")
            case .blocked: String(localized: "This has words Apple Intelligence won’t learn from. Bleep them (f***) or pick another example.")
            }
        }
    }

    // MARK: - Blocked words

    /// Strong swearing, slurs and self-harm phrasing: never written, whatever the swearing setting says.
    private static let strongStems = [
        "fuck", "fuk", "fck", "shit", "bitch", "cunt", "asshol", "bastard", "pussy", "motherf", "dickhead", "wank", "twat",
        "porra", "caralh", "merd", "buceta", "cacet", "arrombad", "fdp", "vtnc", "mierd", "joder", "putain", "scheis", "cazz",
    ]
    /// Whole words that look like a stem inside something harmless ("computador", "reputation").
    private static let wholeWordStems: Set<String> = ["puta", "jod", "cono", "dick", "pqp"]
    private static let allowed: Set<String> = [
        "hello", "shell", "scunthorpe", "assess", "class", "pass", "shiitake", "cocktail", "computador", "computation", "reputation",
        "disputa", "jodhpur", "merdeka", "dickens", "drogaria",
    ]
    private static let harmfulPhrases = ["how to make a bomb", "kill yourself", "suicide method"]

    static func isBlocked(_ text: String) -> Bool {
        let folded = key(text)
        if harmfulPhrases.contains(where: { folded.contains($0) }) { return true }
        let words = folded.split { !$0.isLetter }.map(String.init)
        return words.contains { word in
            if allowed.contains(word) { return false }
            if wholeWordStems.contains(word) { return true }
            return strongStems.contains { word.hasPrefix($0) }
        }
    }

    // MARK: - "Did you mean"

    /// The option this text is a small typo of, if any (a edit distance of 1, or 2 for long words; never for an exact match).
    static func suggestion(for text: String, in vocabulary: [String]) -> String? {
        let typed = key(text)
        guard typed.count >= 4 else { return nil }
        let allowed = typed.count >= 8 ? 2 : 1
        var best: (option: String, distance: Int)?
        for option in vocabulary {
            let candidate = key(option)
            guard abs(candidate.count - typed.count) <= allowed else { continue }
            let distance = editDistance(typed, candidate)
            if distance >= 1, distance <= allowed, distance < (best?.distance ?? .max) { best = (option, distance) }
        }
        return best?.option
    }

    /// Lowercased, without accents or case, to compare what people type.
    static func key(_ text: String) -> String {
        text.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func editDistance(_ a: String, _ b: String) -> Int {
        let left = Array(a), right = Array(b)
        if left.isEmpty { return right.count }
        if right.isEmpty { return left.count }
        var previous = Array(0...right.count)
        for (i, l) in left.enumerated() {
            var current = [i + 1]
            for (j, r) in right.enumerated() {
                current.append(min(previous[j + 1] + 1, current[j] + 1, previous[j] + (l == r ? 0 : 1)))
            }
            previous = current
        }
        return previous[right.count]
    }
}
