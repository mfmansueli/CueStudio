//
//  CardSkyTests.swift
//  Cue StudioTests
//

import Testing
@testable import Cue_Studio

@Suite("Card sky")
struct CardSkyTests {
    @Test func theTwinkleFollowsTheBoardsKeyframes() {
        // The board's `@keyframes twinkle`: opacity 0.2 / 1 / 0.45 / 0.95 / 0.25 / 1 / 0.5 at 0 / 12 / 22 / 38 / 55 / 72 / 86%.
        #expect(CardSky.value(at: 0).opacity == 0.2)
        #expect(abs(CardSky.value(at: 0.12).opacity - 1) < 0.0001)
        #expect(abs(CardSky.value(at: 0.38).opacity - 0.95) < 0.0001)
        #expect(abs(CardSky.value(at: 0.72).scale - 1.3) < 0.0001)
        // Halfway between 12% and 22% it is halfway between 1 and 0.45.
        #expect(abs(CardSky.value(at: 0.17).opacity - 0.725) < 0.0001)
    }
}
