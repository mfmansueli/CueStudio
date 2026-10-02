//
//  SpeechUseTests.swift
//  Cue StudioTests
//

import Testing
@testable import Cue_Studio

/// What each use of the recognizer keeps and how it joins what it hears: Voice Following keeps a
/// short tail (and always joined with a space, as ever); dictation keeps every word, and never
/// puts a space inside writing that has none.
@Suite("Speech use")
struct SpeechUseTests {
    @Test func followingKeepsAShortTailAndDictationKeepsEverything() {
        #expect(SpeechUse.following.transcriptLimit == 400)
        #expect(SpeechUse.dictation.transcriptLimit == nil)
    }

    @Test func followingAlwaysJoinsWithASpace() {
        #expect(SpeechUse.following.separator(after: "", before: "hello") == " ")
        #expect(SpeechUse.following.separator(after: "今日は", before: "天気") == " ")
    }

    @Test func dictationJoinsLatinWordsWithASpace() {
        #expect(SpeechUse.dictation.separator(after: "hello", before: "world") == " ")
        #expect(SpeechUse.dictation.separator(after: "Olá.", before: "Tudo bem?") == " ")
    }

    @Test func dictationAddsNothingBeforeTheFirstWordOrAcrossUnspacedWriting() {
        #expect(SpeechUse.dictation.separator(after: "", before: "hello") == "")
        #expect(SpeechUse.dictation.separator(after: "今日は", before: "天気がいい") == "")
        #expect(SpeechUse.dictation.separator(after: "สวัสดี", before: "ครับ") == "")
        #expect(SpeechUse.dictation.separator(after: "hello ", before: "world") == "")
    }
}
