//
//  FormatGuess.swift
//  Cue Studio
//

import Foundation

/// The format a free idea most likely wants when the creator didn't pick one: read from the idea, then from what they film most. Only used to tell
/// the AI the shape (`FormatGuide`); nothing is saved under it, and the creator's own choice always wins.
nonisolated enum FormatGuess {
    /// - Parameter idea: what the creator typed.
    /// - Parameter usual: the formats they film most, first the likeliest.
    static func format(for idea: String, usual: [ScriptType]) -> ScriptType? {
        let text = idea.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        let candidate = fromIdea(text)
        // What the idea says wins, as long as the creator hasn't said they never film it; a vague idea takes what they film most.
        if let candidate, usual.isEmpty || usual.contains(candidate) || isUnambiguous(candidate) { return candidate }
        return usual.first { general.contains($0) }
    }

    private static func fromIdea(_ text: String) -> ScriptType? {
        if text.contains(/\bmyth\b|\bmyths\b|\bnot true\b|\bwrong about\b|\bbelief\b/) { return .mythFact }
        if text.contains(/^pov\b|\bpov:/) { return .pov }
        if text.contains(/^(how to|how i|how we|how do|how can|steps to|the easiest way|a simple way)\b/) { return .tutorial }
        if text.contains(/\b\d+\s+(tips?|ways?|things?|habits?|mistakes?|rules?|reasons?|hacks?|ideas?|steps?|signs?)\b/)
            || text.contains(/^(three|five|seven|ten|top)\s/) { return .list }
        if text.contains(/\b(review|unboxing|first impressions?|worth it|honest)\b/) { return .review }
        if text.contains(/^(why i|why we|the day i|when i|what happened|the time)\b/) { return .story }
        if text.contains(/\b(unpopular|hot take|stop doing|overrated|underrated|i disagree)\b/) { return .opinion }
        if text.contains(/\b(announcing|launch|launching|new product|just dropped|big news)\b/) { return .launch }
        return nil
    }

    /// The shapes that suit an idea that says nothing of its own: a review needs a product, an announcement news, an ad a brand, an apology a reason.
    private static let general: Set<ScriptType> = [.story, .opinion, .list, .tutorial]

    /// A myth, a POV or a numbered list says what it is.
    private static func isUnambiguous(_ type: ScriptType) -> Bool {
        type == .mythFact || type == .pov || type == .list || type == .tutorial
    }
}
