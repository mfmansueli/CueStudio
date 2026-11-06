//
//  LocalizedStringCacheTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

/// The interface's strings looked up once per language (`LocalizedStringCache`): the same words as Foundation's lookup, each value of a
/// string with values in it kept apart, each language apart, and much faster the second time.
@Suite(.serialized)
struct LocalizedStringCacheTests {
    private func resource(_ value: String.LocalizationValue, in identifier: String) -> LocalizedStringResource {
        var resource = LocalizedStringResource(value)
        resource.locale = Locale(identifier: identifier)
        return resource
    }

    @Test func aStringIsTheSameAsFoundationsLookupInEachLanguage() {
        LocalizedStringCache.removeAll()
        for identifier in ["en", "pt-BR", "ja", "ar"] {
            let uncached = String(localized: resource("Folder created", in: identifier))
            #expect(LocalizedStringCache.string(for: resource("Folder created", in: identifier)) == uncached)
            #expect(LocalizedStringCache.string(for: resource("Folder created", in: identifier)) == uncached, "Second time, from the cache")
        }
        #expect(
            LocalizedStringCache.string(for: resource("Folder created", in: "pt-BR"))
                != LocalizedStringCache.string(for: resource("Folder created", in: "en")),
            "Each language keeps its own"
        )
    }

    @Test func eachValueInAStringIsKeptApart() {
        LocalizedStringCache.removeAll()
        let two = LocalizedStringCache.string(for: resource("Ultra AI · \(2) of \(3) free left", in: "en"))
        let one = LocalizedStringCache.string(for: resource("Ultra AI · \(1) of \(3) free left", in: "en"))
        #expect(two.contains("2") && one.contains("1"))
        #expect(two != one)
        #expect(LocalizedStringCache.string(for: resource("Ultra AI · \(2) of \(3) free left", in: "en")) == two)
    }

    @Test func onlyTheNewestValuesOfAStringStay() {
        LocalizedStringCache.removeAll()
        for count in 0..<(LocalizedStringCache.versionsPerKey * 3) {
            let text = LocalizedStringCache.string(for: resource("\(count) ideas waiting", in: "en"))
            #expect(text.contains("\(count)"))
        }
    }

    @Test func theSecondLookupIsFasterThanFoundations() {
        LocalizedStringCache.removeAll()
        let keys: [String.LocalizationValue] = ["Folder created", "Folder deleted", "Duplicated", "Undo", "Ready to record"]
        let clock = ContinuousClock()
        let uncached = clock.measure {
            for _ in 0..<200 { for key in keys { _ = String(localized: resource(key, in: "pt-BR")) } }
        }
        for key in keys { _ = LocalizedStringCache.string(for: resource(key, in: "pt-BR")) }
        let cached = clock.measure {
            for _ in 0..<200 { for key in keys { _ = LocalizedStringCache.string(for: resource(key, in: "pt-BR")) } }
        }
        #expect(cached * 5 < uncached, "1000 lookups: Foundation \(uncached), cached \(cached)")
    }

    @Test func aScriptsWordsCountedOnceAreTheSameAndFasterAgain() {
        let script = String(repeating: "Today I show you three ways to film yourself [pause] without a crew. ", count: 120)
        let first = ReadTime.wordCount(in: script)
        #expect(first == 12 * 120, "Cues aren't words")
        #expect(ReadTime.wordCount(in: script) == first, "From what was kept")
        #expect(ReadTime.wordCount(in: script + " One more.") == first + 2, "A changed text is counted again")
        #expect(ReadTime.wordCount(in: "今日は三つの方法を紹介します") > 1, "Unspaced scripts still count dictionary words")
        let clock = ContinuousClock()
        let texts = (0..<40).map { "\(script) \($0)" }
        let counted = clock.measure { for text in texts { _ = ReadTime.wordCount(in: text) } }
        let again = clock.measure { for text in texts { _ = ReadTime.wordCount(in: text) } }
        #expect(again * 5 < counted, "40 scripts: counted \(counted), again \(again)")
    }

    @Test func aLanguageReadOnceIsTheSameReadAgain() {
        let text = "Ontem eu acordei cedo e fui correr na praia antes do trabalho, e foi o melhor dia da semana."
        let first = LanguageDetector.quickLanguage(in: text)
        #expect(first == LanguageDetector.quickLanguage(in: text))
        #expect(LanguageDetector.dominantLanguageCode(in: text) == "pt")
        #expect(LanguageDetector.dominantLanguageCode(in: text) == "pt", "From what was kept")
        #expect(LanguageDetector.dominantLanguageCode(in: "I woke up early and went for a run on the beach before work today.") == "en")
        #expect(LanguageDetector.quickLanguage(in: "oi") == nil, "Too short to tell, kept as nothing")
        #expect(LanguageDetector.quickLanguage(in: "oi") == nil)
    }
}
