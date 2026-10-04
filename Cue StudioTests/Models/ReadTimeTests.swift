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
}
