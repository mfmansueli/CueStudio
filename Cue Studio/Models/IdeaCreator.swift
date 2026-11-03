//
//  IdeaCreator.swift
//  Cue Studio
//

import Foundation

/// Who the ideas are for: the creator's kind and what their videos are for, as the creator said them in My Cue Voice (`CreatorProfile.ideaCreator`).
/// The owner (03/11/2026): the ideas are made from what the creator tells Cue, so a lawyer who wants clients and to raise awareness gets ideas that
/// explain rights to people and bring clients, not a law student's. Like the topics, it goes with every request for ideas, the voice on or off: it
/// says what the videos are for, never how they sound.
nonisolated struct IdeaCreator: Hashable, Sendable {
    /// Who they are, for the AI ("a lawyer who explains people's rights in plain words"); nil when they didn't say.
    var who: String?
    var goals: [ContentGoal] = []

    /// The line the ideas are asked with; nil when there is nothing to say.
    var promptLine: String? { line(serving: "the ideas") }

    /// The same, for what else is asked around the ideas ("the subjects", `IdeaIngredients`).
    func line(serving what: String) -> String? {
        var parts: [String] = []
        if let who { parts.append("The creator is \(who).") }
        if !goals.isEmpty {
            let aims = goals.map(\.promptPhrase)
            let list = aims.count == 1 ? aims[0] : aims.dropLast().joined(separator: ", ") + " and " + (aims.last ?? "")
            parts.append("Their videos aim to \(list), and \(what) serve that.")
        }
        return parts.isEmpty ? nil : parts.joined(separator: " ")
    }
}

nonisolated extension CreatorProfile {
    /// Who the ideas are for; nil when the creator said neither who they are nor what their videos are for.
    var ideaCreator: IdeaCreator? {
        let creator = IdeaCreator(who: customRole ?? kind?.promptName ?? role?.promptName, goals: contentGoals)
        return creator.promptLine == nil ? nil : creator
    }
}
