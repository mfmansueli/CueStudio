//
//  CaptionErrorRate.swift
//  Cue StudioTests
//

import Foundation
@testable import Cue_Studio

/// The share of a script's words (letters, for the languages written without spaces and Korean) that a caption gets wrong:
/// left out, added or different, after case, punctuation and width are set aside. Traditional and Simplified Chinese count as
/// the same.
enum CaptionErrorRate {
    static func of(_ words: [String], against script: String, language: CueLanguage) -> Double {
        let reference = tokens(of: script, language: language)
        let caption = tokens(of: words.joined(separator: " "), language: language)
        return Double(distance(reference, caption)) / Double(max(1, reference.count))
    }

    static func tokens(of text: String, language: CueLanguage) -> [String] {
        var folded = text.precomposedStringWithCompatibilityMapping.lowercased()
        if language == .chineseTraditional || language == .chineseSimplified {
            folded = folded.applyingTransform(StringTransform("Hant-Hans"), reverse: false) ?? folded
        }
        let spaced = String(folded.map { $0.isLetter || $0.isNumber || $0.unicodeScalars.contains(where: \.properties.isDiacritic) ? $0 : " " })
        if language.writesWithoutSpaces || language == .korean {
            return spaced.filter { !$0.isWhitespace }.map(String.init)
        }
        return spaced.split(separator: " ").map(String.init)
    }

    private static func distance(_ first: [String], _ second: [String]) -> Int {
        var previous = Array(0...second.count)
        for (i, a) in first.enumerated() {
            var row = [i + 1] + Array(repeating: 0, count: second.count)
            for (j, b) in second.enumerated() {
                row[j + 1] = min(previous[j + 1] + 1, row[j] + 1, previous[j] + (a == b ? 0 : 1))
            }
            previous = row
        }
        return previous[second.count]
    }
}
