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

    /// The specifiers of a string, without positions: how many of which kind (`sorted`), or in the order they appear.
    private static func specifiers(in text: String, sorted: Bool = true) -> [String] {
        var found: [String] = []
        var searchRange = text.startIndex..<text.endIndex
        while let range = text.range(of: specifierPattern, options: .regularExpression, range: searchRange) {
            found.append(text[range].replacingOccurrences(of: #"\d+\$"#, with: "", options: .regularExpression))
            searchRange = range.upperBound..<text.endIndex
        }
        return sorted ? found.sorted() : found
    }

    /// An iPhone in a regional variant Cue has no localization of gets the language, not English, even with English
    /// second in its list: iOS prefers English over a localization whose region doesn't match (pt-BR for pt-PT).
    @Test(arguments: [
        (["pt-PT", "en-PT"], "pt"), (["pt-BR", "en-BR"], "pt"), (["es-US", "en-US"], "es"), (["es-419", "en"], "es"),
        (["fr-CA", "en-CA"], "fr"), (["de-AT", "en-AT"], "de"), (["zh-HK", "en-HK"], "zh-Hant"), (["zh-Hans-SG", "en-SG"], "zh-Hans"),
        (["nn-NO", "en-NO"], "nb"), (["ar-EG", "en"], "ar"), (["en-GB"], "en"),
    ])
    func aRegionalVariantGetsItsLanguage(preferences: [String], expected: String) {
        #expect(Bundle.preferredLocalizations(from: Bundle.main.localizations, forPreferences: preferences).first == expected)
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
        var reordered: [String] = []
        for (key, text) in table {
            guard let source = english[key] else { continue }
            if Self.specifiers(in: text) != Self.specifiers(in: source) { mismatched.append(key) }
            // Unnumbered specifiers fill in order: a translation that moves "%@" before "%lld" without numbering them
            // hands the number to the text one (a crash or garbage). Reordering needs %1$lld / %2$@.
            if !text.contains("$"), Self.specifiers(in: text, sorted: false) != Self.specifiers(in: source, sorted: false) {
                reordered.append(key)
            }
            if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, !source.isEmpty { mismatched.append(key) }
        }
        #expect(mismatched.isEmpty, "\(language.interfaceLocalization): placeholders differ in \(mismatched.prefix(5))")
        #expect(reordered.isEmpty, "\(language.interfaceLocalization): placeholders moved without numbers in \(reordered.prefix(5))")
    }

    /// No dashes in any language (the owner's rule, LOCALIZATION.md §2.1): em and en dashes, the horizontal bar and their
    /// small and fullwidth forms. Hyphens inside words, the minus sign and Japanese ー are other characters and stay.
    @Test(arguments: CueLanguage.allCases)
    func noStringHasADash(language: CueLanguage) throws {
        let dashes = CharacterSet(charactersIn: "\u{2012}\u{2013}\u{2014}\u{2015}\u{2E3A}\u{2E3B}\u{FE58}\u{FE63}\u{FF0D}")
        for table in ["Localizable", "InfoPlist", "AppShortcuts"] {
            guard let path = Bundle.main.path(forResource: table, ofType: "strings", inDirectory: nil, forLocalization: language.interfaceLocalization),
                  let strings = NSDictionary(contentsOfFile: path) as? [String: String] else { continue }
            let dashed = strings.filter { $0.value.rangeOfCharacter(from: dashes) != nil }.map(\.key).sorted()
            #expect(dashed.isEmpty, "\(language.interfaceLocalization) \(table) has dashes in \(dashed.prefix(5))")
        }
    }

    @Test func theStringsThisWorkAddedAreInEveryLanguage() throws {
        let keys = [
            // The key the code looks up (`ScriptAIError`): two interpolations make two %@; translations may number them.
            "Apple Intelligence can’t translate between %@ and %@ yet.",
            "The result wasn’t in the right language, so your script is unchanged. Try again.",
            "Captions couldn’t listen for %@ in this take, so those parts may be missing. Check the lines or write them yourself.",
            "Apple Intelligence needs a short break. Try again in a few minutes.",
        ]
        for language in CueLanguage.allCases where language != .english {
            let table = try #require(Self.strings(language.interfaceLocalization))
            for key in keys {
                let text = try #require(table[key], "\(language.interfaceLocalization) lacks “\(key.prefix(40))…”")
                #expect(text != key, "\(language.interfaceLocalization) left “\(key.prefix(40))…” in English")
            }
        }
    }

    @Test func theSharingMessagesAreInEveryLanguage() throws {
        let keys = [
            "Shared with %@",
            "Sharing cancelled",
            "Couldn’t share · Try again",
            "%@ isn’t on this iPhone · Pick another app",
            "Opened %@ with your video · Cue can’t see if you post it",
            "%@ didn’t take the video",
            "Saved to Photos · Open %@ to post it",
        ]
        for language in CueLanguage.allCases where language != .english {
            let table = try #require(Self.strings(language.interfaceLocalization))
            for key in keys {
                let text = try #require(table[key], "\(language.interfaceLocalization) lacks “\(key.prefix(40))…”")
                #expect(text != key, "\(language.interfaceLocalization) left “\(key.prefix(40))…” in English")
                #expect(Self.specifiers(in: text) == Self.specifiers(in: key), "\(language.interfaceLocalization) changed the placeholders of “\(key.prefix(40))…”")
            }
        }
    }
}
