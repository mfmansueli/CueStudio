//
//  TimedWord.swift
//  Cue Studio
//

import Foundation

/// A word heard in the take, with when it was said.
nonisolated struct TimedWord: Hashable, Sendable {
    var text: String
    var start: TimeInterval
    var end: TimeInterval

    /// The word as Clean Up compares it: lowercased, without punctuation, and a sound held long
    /// ("ummmm") the same as a short one ("umm").
    var spoken: String {
        var result = ""
        var run = 0
        for character in text.lowercased() where character.isLetter || character.isNumber || character == "'" {
            run = character == result.last ? run + 1 : 1
            if run <= 2 { result.append(character) }
        }
        return result
    }

    /// Said as an exclamation or a question ("Ah!"), which usually means it matters.
    var isEmphatic: Bool {
        text.contains { $0 == "!" || $0 == "?" }
    }

    /// Whether `phrase` (spoken forms) is said in `spoken` starting at `index`.
    static func phrase(_ phrase: [String], isSaidIn spoken: [String], at index: Int) -> Bool {
        !phrase.isEmpty && index >= 0 && index + phrase.count <= spoken.count
            && spoken[index..<index + phrase.count].elementsEqual(phrase)
    }

    /// The words from `first` through `last`, as said.
    static func text(of words: [TimedWord], from first: Int, through last: Int) -> String {
        words[first...last].map(\.text).joined(separator: " ")
    }
}
