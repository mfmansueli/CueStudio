//
//  TopicCasingTests.swift
//  Cue StudioTests
//

import Testing
@testable import Cue_Studio

/// A typed topic inside a starter's sentence (`TopicCasing`): the field's capital goes from common words, names keep theirs, German keeps its
/// nouns', and a sentence that starts with the topic still starts with a capital.
@MainActor
@Suite("Topic casing")
struct TopicCasingTests {
    @Test func aCommonWordLosesTheFieldsCapital() {
        #expect(TopicCasing.inSentence("Rotina", language: "pt") == "rotina")
        #expect(TopicCasing.inSentence("Daily Routine", language: "en") == "daily routine")
        #expect(TopicCasing.inSentence("Cocina", language: "es") == "cocina")
    }

    @Test func namesAndMixedCapitalsStay() {
        #expect(TopicCasing.inSentence("YouTube", language: "en") == "YouTube")
        #expect(TopicCasing.inSentence("iPhone", language: "pt") == "iPhone")
        #expect(TopicCasing.inSentence("Instagram", language: "pt") == "Instagram")
        #expect(TopicCasing.inSentence("SEO", language: "en") == "SEO")
        #expect(TopicCasing.inSentence("Italian", language: "en") == "Italian")
    }

    @Test func germanKeepsItsNounsCapital() {
        #expect(TopicCasing.inSentence("Routine", language: "de") == "Routine")
    }

    @Test func aSentenceStartsWithACapital() {
        #expect(TopicCasing.sentenceStart("rotina: o erro de quem começa") == "Rotina: o erro de quem começa")
        #expect(TopicCasing.sentenceStart("Mitos sobre rotina") == "Mitos sobre rotina")
        #expect(TopicCasing.sentenceStart("") == "")
    }
}
