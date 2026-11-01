//
//  ReadTimeTests.swift
//  Cue StudioTests
//

import Testing
@testable import Cue_Studio

@Suite("ReadTime")
struct ReadTimeTests {
    @Test func cuesAreNotCountedAsWords() {
        #expect(ReadTime.wordCount(in: "Okay, real talk. [pause] Three tiny [look at camera]") == 5)
    }

    @Test func oneXReads215WordsPerMinute() {
        #expect(ReadTime.seconds(for: TestData.words(215), speed: 1) == 60)
    }

    @Test func theDefaultSpeedIsANaturalPaceOfAbout150WordsPerMinute() {
        #expect(abs(ReadTime.naturalSpeed - 0.7) < 0.005)
        #expect(ReadTime.wordsPerMinute(speed: ReadTime.naturalSpeed) == 150)
        #expect(abs(ReadTime.wordsPerMinute(speed: ReadTime.naturalSpeed) - 150) < 1)
        #expect(abs(ReadTime.seconds(for: TestData.words(150)) - 60) < 0.5)
    }

    @Test func fasterSpeedShortensTheReadTime() {
        #expect(ReadTime.seconds(for: TestData.words(215), speed: 2) == 30)
    }

    @Test func wordsForSecondsIsTheInverse() {
        #expect(ReadTime.words(for: 60, speed: 1) == 215)
        #expect(ReadTime.words(for: 120, speed: 0.5) == 215)
        #expect(abs(ReadTime.words(for: 90) - 225) <= 1)
    }
    /// A minute holds fewer words in Korean and more in French (`ReadTime.pace(for:)`): the same 150 words run longer in Korean, shorter in
    /// French, and English (or an unknown language) is as before.
    @Test func eachLanguageIsTimedAtItsOwnPace() {
        let text = TestData.words(150)
        #expect(abs(ReadTime.seconds(for: text) - 60) < 0.01)
        #expect(abs(ReadTime.seconds(for: text, language: .english) - 60) < 0.01)
        #expect(abs(ReadTime.seconds(for: text, language: .korean) - 80) < 0.01)
        #expect(ReadTime.seconds(for: text, language: .french) < 53)
        #expect(ReadTime.words(for: 60, language: .korean) == 113)
        #expect(ReadTime.words(for: 60, language: .portugueseBrazil) == 150)
    }

    /// A script the creator wrote has no language set: it is timed at the pace of the language its words are in, the same in the list and on
    /// the page.
    @Test func aScriptWithoutALanguageIsTimedByItsWords() {
        let korean = TestData.script(text: "오늘은 제가 아침에 하는 세 가지 습관을 알려 드릴게요. 첫 번째는 일어나자마자 물 한 잔을 마시는 거예요.")
        #expect(korean.paceLanguage == .korean)
        #expect(korean.readSeconds == ReadTime.seconds(for: korean.text, language: .korean))
        var set = korean
        set.language = .english
        #expect(set.paceLanguage == .english)
    }
}
