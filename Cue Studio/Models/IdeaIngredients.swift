//
//  IdeaIngredients.swift
//  Cue Studio
//

import Foundation

/// The concrete things a topic's videos can be about, in the creator's language and of their country's daily life, written by Private Cloud
/// Compute's larger model: one goes into each idea the iPhone's model is asked for (`IdeaSlot.subject`), so it writes about something particular
/// instead of the topic in general. Measured on an iPhone in Portuguese and Spanish (`IdeaLanguageDeviceTests`, 03/11/2026): ideas about a
/// concrete subject went from 0 in 34 without them to 23 in 36 with these (12 in 36 with the iPhone model's own, which read vaguer).
nonisolated struct IdeaIngredients: Codable, Hashable, Sendable {
    var beliefs: [String] = []
    var mistakes: [String] = []
    var moments: [String] = []
    var things: [String] = []

    /// Longest a subject may be: past it, the model wrote a sentence or a title instead of a subject.
    static let longest = 70

    func subjects(_ kind: IdeaIngredientKind) -> [String] {
        switch kind {
        case .belief: beliefs
        case .mistake: mistakes
        case .moment: moments
        case .thing: things
        }
    }

    mutating func set(_ subjects: [String], for kind: IdeaIngredientKind) {
        switch kind {
        case .belief: beliefs = subjects
        case .mistake: mistakes = subjects
        case .moment: moments = subjects
        case .thing: things = subjects
        }
    }

    var isEmpty: Bool { IdeaIngredientKind.allCases.allSatisfy { subjects($0).isEmpty } }

    /// The model's lists made usable: each subject trimmed of spaces and of a closing period, none empty, too long or said twice.
    func cleaned() -> IdeaIngredients {
        var seen = Set<String>()
        func clean(_ list: [String]) -> [String] {
            list.compactMap { item -> String? in
                let subject = item.trimmingCharacters(in: .whitespacesAndNewlines.union(CharacterSet(charactersIn: ".;")))
                guard !subject.isEmpty, subject.count <= Self.longest, seen.insert(subject.lowercased()).inserted else { return nil }
                return subject
            }
        }
        return IdeaIngredients(beliefs: clean(beliefs), mistakes: clean(mistakes), moments: clean(moments), things: clean(things))
    }
}
