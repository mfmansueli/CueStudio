//
//  TopicCasing.swift
//  Cue Studio
//

import Foundation
import UIKit

/// A topic the creator typed, as it reads inside a starter's sentence: the field capitalizes the first letter ("Rotina"), so "Mitos sobre
/// Rotina" read like a name. A word that is only capitalized and that the language's dictionary knows in lowercase loses its capital
/// ("Mitos sobre rotina"); a name stays as it is ("Instagram", "YouTube", "Italian" in English), and German keeps every noun's capital.
/// The sentence then starts with a capital wherever the topic landed (`sentenceStart`).
nonisolated enum TopicCasing {
    /// Languages whose nouns always start with a capital.
    private static let capitalizedNouns: Set<String> = ["de", "lb"]

    static func inSentence(_ name: String, language: String?) -> String {
        guard let code = language.map({ Locale.Language(identifier: $0).languageCode?.identifier ?? $0 }),
              !capitalizedNouns.contains(code) else { return name }
        let words = name.split(separator: " ", omittingEmptySubsequences: false).map(String.init)
        return words.map { word in
            guard isOnlyCapitalized(word) else { return word }
            let lower = word.lowercased()
            return isKnownWord(lower, language: language ?? code) ? lower : word
        }.joined(separator: " ")
    }

    /// `text` with a capital first letter, for a sentence that starts with a topic made lowercase.
    static func sentenceStart(_ text: String) -> String {
        guard let first = text.first, first.isLowercase else { return text }
        return first.uppercased() + text.dropFirst()
    }

    /// "Rotina", not "iPhone", "TikTok", "ROTINA" or "rotina".
    private static func isOnlyCapitalized(_ word: String) -> Bool {
        guard word.count >= 2, let first = word.first, first.isUppercase else { return false }
        let rest = word.dropFirst()
        return rest.contains(where: \.isLetter) && rest == rest.lowercased()
    }

    /// Whether the dictionary of `language` knows `word` as it is (lowercase). Only on the main thread, where the text checker lives (the
    /// starters are made there, by `IdeaSuggestionService`); elsewhere the topic keeps the creator's capital.
    private static func isKnownWord(_ word: String, language: String) -> Bool {
        guard Thread.isMainThread else { return false }
        return MainActor.assumeIsolated {
            let code = Locale.Language(identifier: language).languageCode?.identifier ?? language
            let available = UITextChecker.availableLanguages
            guard let dictionary = available.first(where: { $0 == language.replacingOccurrences(of: "-", with: "_") })
                ?? available.first(where: { $0.hasPrefix(code) }) else { return false }
            let range = UITextChecker().rangeOfMisspelledWord(
                in: word, range: NSRange(location: 0, length: (word as NSString).length), startingAt: 0, wrap: false, language: dictionary
            )
            return range.location == NSNotFound
        }
    }
}
