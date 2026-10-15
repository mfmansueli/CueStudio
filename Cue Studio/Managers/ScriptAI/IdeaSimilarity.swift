//
//  IdeaSimilarity.swift
//  Cue Studio
//

import Foundation

/// Whether two ideas are the same idea said twice. The model rewords a title and calls it new, or keeps the title new and brings back the same angle
/// and the same first sentence: one idea is a repeat of another when their titles are nearly the same words, or when two of the three things the
/// creator reads (title, angle, the start of the opening line) are largely the same. Ideas about different topics only repeat each other by their
/// titles: the same kind of angle about another subject is another video, not a repeat.
nonisolated enum IdeaSimilarity {
    /// The meaningful words of a title, folded to lowercase without accents, and its numbers ("3 habits" and "7 habits" are not one title).
    static func words(in title: String) -> Set<String> {
        let numbers = title.split { !$0.isNumber }.map(String.init)
        return Set(IdeaFocus.words(in: title, language: nil).filter { $0.count >= 3 } + numbers)
    }

    /// Alike when most of the shorter title's words are in the other.
    static func areAlike(_ lhs: Set<String>, _ rhs: Set<String>) -> Bool {
        guard !lhs.isEmpty, !rhs.isEmpty else { return lhs == rhs }
        return overlap(lhs, rhs) >= 0.75
    }

    /// The share of a part counted as the same part said again: half of the shorter one's words.
    static let partShare = 0.5

    /// `idea` says again what `other` said: its title nearly, or two of its parts, about the same topic.
    static func repeats(_ idea: IdeaEcho, _ other: IdeaEcho) -> Bool {
        if areAlike(idea.title, other.title) { return true }
        if let topic = idea.topic, let otherTopic = other.topic, topic != otherTopic { return false }
        let parts = [(idea.title, other.title), (idea.angle, other.angle), (idea.opening, other.opening)]
        let same = parts.filter { lhs, rhs in lhs.count >= 2 && rhs.count >= 2 && overlap(lhs, rhs) >= partShare }.count
        return same >= 2
    }

    /// The share of the shorter set's words found in the other.
    static func overlap(_ lhs: Set<String>, _ rhs: Set<String>) -> Double {
        guard !lhs.isEmpty, !rhs.isEmpty else { return 0 }
        return Double(lhs.intersection(rhs).count) / Double(min(lhs.count, rhs.count))
    }

    /// The first sentence of an opening line: where two lines that start the same video meet.
    static func firstSentence(of text: String) -> String {
        let end = text.firstIndex { ".?!。？！".contains($0) }
        return end.map { String(text[...$0]) } ?? text
    }
}
