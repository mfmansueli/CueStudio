//
//  PrompterBoxTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

@Suite("PrompterSettings · box and reading line")
struct PrompterBoxTests {
    @Test func theBoxIsTheTextWindowSoNothingIsSavedTwice() throws {
        var settings = PrompterSettings()
        settings.boxWidth = 0.7
        settings.boxHeight = 250
        #expect(settings.readingWidth == 0.7)
        #expect(settings.textWindowHeight == 250)
        let decoded = try JSONDecoder().decode(PrompterSettings.self, from: JSONEncoder().encode(settings))
        #expect(decoded.boxWidth == 0.7)
        #expect(decoded.boxHeight == 250)
    }

    @Test func theBoxIsHeldToItsRange() {
        var settings = PrompterSettings()
        settings.boxWidth = 5
        settings.boxHeight = 10
        #expect(settings.boxWidth == PrompterSettings.readingWidthRange.upperBound)
        #expect(settings.boxHeight == PrompterSettings.textWindowHeightRange.lowerBound)
    }

    @Test func theReadingLineIsAFractionOfTheScreenHeldBetweenTenAndFiftyPercent() {
        var settings = PrompterSettings()
        let screen = ReadingLinePercent(screenHeight: 800, lensY: 30)
        settings.setReadingLine(0.3, on: screen)
        #expect(abs(settings.readingLine(on: screen) - 0.3) < 0.01)
        settings.setReadingLine(0.9, on: screen)
        #expect(abs(settings.readingLine(on: screen) - 0.5) < 0.01)
        settings.setReadingLine(0, on: screen)
        #expect(abs(settings.readingLine(on: screen) - 0.1) < 0.01)
    }

    @Test func theSameFractionLandsInTheSameRelativeSpotOnAnotherScreen() {
        var settings = PrompterSettings()
        let small = ReadingLinePercent(screenHeight: 667, lensY: 20)
        let big = ReadingLinePercent(screenHeight: 932, lensY: 59)
        settings.setReadingLine(0.25, on: small)
        let stored = settings.readingLineOffset
        settings.setReadingLine(0.25, on: big)
        #expect(settings.readingLineOffset != stored)
        #expect(abs(settings.readingLine(on: big) - 0.25) < 0.01)
    }
}
