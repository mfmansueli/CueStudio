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

    @Test func readsAt150WordsPerMinuteAtNormalSpeed() {
        #expect(ReadTime.seconds(for: TestData.words(150)) == 60)
    }

    @Test func fasterSpeedShortensTheReadTime() {
        #expect(ReadTime.seconds(for: TestData.words(150), speed: 2) == 30)
    }

    @Test func wordsForSecondsIsTheInverse() {
        #expect(ReadTime.words(for: 60) == 150)
        #expect(ReadTime.words(for: 90) == 225)
    }
}
