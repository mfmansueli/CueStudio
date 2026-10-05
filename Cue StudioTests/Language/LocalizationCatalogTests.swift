//
//  LocalizationCatalogTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

/// The String Catalog as the app ships it, in each of the 20 languages: every string is there, nothing
/// is left in English by mistake, and what a string asks to be filled in (`%@`, `%lld`) is what the
/// English one asks for, in the same number, so no translation can crash or drop a value.
/// Reads the compiled `.lproj` of the app the tests run in (not the project's files).
@Suite("Localization catalog")
struct LocalizationCatalogTests {
    private static let specifierPattern = #"%(?:\d+\$)?(?:l{1,2}|h{1,2}|z|q)?[@dDuUxXoOfeEgGcCsSp]"#

    private static func strings(_ localization: String) -> [String: String]? {
        guard let path = Bundle.main.path(forResource: "Localizable", ofType: "strings", inDirectory: nil, forLocalization: localization),
              let table = NSDictionary(contentsOfFile: path) as? [String: String] else { return nil }
        return table
    }

    /// The specifiers of a string, without positions: how many of which kind.
    private static func specifiers(in text: String) -> [String] {
        var found: [String] = []
        var searchRange = text.startIndex..<text.endIndex
        while let range = text.range(of: specifierPattern, options: .regularExpression, range: searchRange) {
            found.append(text[range].replacingOccurrences(of: #"\d+\$"#, with: "", options: .regularExpression))
            searchRange = range.upperBound..<text.endIndex
        }
        return found.sorted()
    }

    @Test(arguments: CueLanguage.allCases)
    func theLanguageIsInTheApp(language: CueLanguage) throws {
        #expect(Bundle.main.localizations.contains { $0.caseInsensitiveCompare(language.interfaceLocalization) == .orderedSame })
        _ = try #require(Self.strings(language.interfaceLocalization), "\(language.interfaceLocalization) has no Localizable.strings")
    }

    @Test(arguments: CueLanguage.allCases.filter { $0 != .english })
    func everyStringIsTranslatedAndKeepsItsPlaceholders(language: CueLanguage) throws {
        let english = try #require(Self.strings("en"))
        let table = try #require(Self.strings(language.interfaceLocalization))
        let missing = english.keys.filter { table[$0] == nil }
        // A key the language leaves out falls back to English: it is only allowed for text that is the same everywhere.
        let leftInEnglish = missing.filter { key in key.contains { $0.isLetter } && key.split(separator: " ").count >= 3 }
        #expect(leftInEnglish.isEmpty, "\(language.interfaceLocalization) is missing \(leftInEnglish.count): \(leftInEnglish.prefix(5))")
        var mismatched: [String] = []
        for (key, text) in table {
            guard let source = english[key] else { continue }
            if Self.specifiers(in: text) != Self.specifiers(in: source) { mismatched.append(key) }
            if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, !source.isEmpty { mismatched.append(key) }
        }
        #expect(mismatched.isEmpty, "\(language.interfaceLocalization): placeholders differ in \(mismatched.prefix(5))")
    }

    @Test func theStringsThisWorkAddedAreInEveryLanguage() throws {
        let keys = [
            "Apple Intelligence can’t translate between %1$@ and %2$@ yet.",
            "The result wasn’t in the right language, so your script is unchanged. Try again.",
            "Captions couldn’t listen for %@ in this take, so those parts may be missing. Check the lines or write them yourself.",
        ]
        for language in CueLanguage.allCases where language != .english {
            let table = try #require(Self.strings(language.interfaceLocalization))
            for key in keys {
                let text = try #require(table[key], "\(language.interfaceLocalization) lacks “\(key.prefix(40))…”")
                #expect(text != key, "\(language.interfaceLocalization) left “\(key.prefix(40))…” in English")
            }
        }
    }
}
