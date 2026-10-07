//
//  IdeaSimilarity.swift
//  Cue Studio
//

import Foundation

/// Whether two ideas are the same idea said twice: the same words, or nearly (the model rewords a title and calls it new).
nonisolated enum IdeaSimilarity {
    /// The meaningful words of a title, folded to lowercase without accents.
    static func words(in title: String) -> Set<String> {
        Set(IdeaFocus.words(in: title, language: nil).filter { $0.count >= 3 })
    }

    /// Alike when most of the shorter title's words are in the other.
    static func areAlike(_ lhs: Set<String>, _ rhs: Set<String>) -> Bool {
        guard !lhs.isEmpty, !rhs.isEmpty else { return lhs == rhs }
        let shared = lhs.intersection(rhs).count
        return Double(shared) / Double(min(lhs.count, rhs.count)) >= 0.75
    }
}
