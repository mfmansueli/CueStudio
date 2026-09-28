//
//  ScriptLengthTests.swift
//  Cue StudioTests
//

import Testing
@testable import Cue_Studio

@Suite("ScriptLength")
struct ScriptLengthTests {
    @Test func autoUsesThePlatformsIdealRange() {
        #expect(ScriptLength.auto.targetRange(ideal: 60...90) == 60...90)
    }

    @Test func fixedLengthsAllowTenPercentEitherWay() {
        #expect(ScriptLength.seconds30.targetRange(ideal: 60...90) == 27...33)
        #expect(ScriptLength.minutes2.targetRange(ideal: 60...90) == 108...132)
    }

    @Test func twoMinutesIsAboutThreeHundredWords() {
        let range = ScriptLength.minutes2.targetRange(ideal: 0...0)
        // At the natural 0.7× (≈150 words a minute).
        #expect(abs(ReadTime.words(for: (range.lowerBound + range.upperBound) / 2) - 300) <= 2)
    }

    @Test(arguments: [
        ("2 minutes on how the electric shower was invented", ScriptLength.minutes2),
        ("A 30-second tip", .seconds30),
        ("one minute on sleep", .minute1),
        ("3 min tutorial", .minutes3),
    ])
    func lengthIsReadFromThePrompt(_ prompt: String, _ expected: ScriptLength) {
        #expect(ScriptLength.detected(in: prompt) == expected)
    }

    @Test func promptsWithoutALengthStayOnAuto() {
        #expect(ScriptLength.detected(in: "My morning routine") == nil)
    }
}
