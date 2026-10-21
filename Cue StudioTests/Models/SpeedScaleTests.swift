//
//  SpeedScaleTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

/// The prompter's speed scale (owner's decision, 20/10/2026): every 0.1× from 0.2× to 2×, 1× the natural pace, each stop exact.
@Suite("SpeedScale")
struct SpeedScaleTests {
    @Test func stopsEveryTenthFromAFifthToTwice() {
        #expect(SpeedScale.stops.count == 19)
        #expect(SpeedScale.stops.first == 0.2)
        #expect(SpeedScale.stops.last == 2)
        #expect(SpeedScale.stops[SpeedScale.defaultStop] == 1)
        for (slower, faster) in zip(SpeedScale.stops, SpeedScale.stops.dropFirst()) {
            #expect(abs(faster - slower - 0.1) < 0.000_001)
        }
    }

    /// A speed saved between two stops (160 words a minute, on the old 5-word steps) reads as the stop the slider shows, everywhere.
    @Test func aSpeedBetweenStopsReadsAsTheNearest() {
        #expect(SpeedScale.label(forSpeed: PrompterSettings.speed(forWordsPerMinute: 160)) == SpeedScale.label(forMultiple: 1.1))
    }

    /// A stop is a whole number of 5-word steps, so the speed the slider stores is the one `clampedSpeed` keeps, and its label is the stop's.
    @Test(arguments: SpeedScale.stops)
    func everyStopIsStoredExactlyAndReadsAsItself(_ multiple: Double) {
        let speed = SpeedScale.speed(forMultiple: multiple)
        #expect(PrompterSettings.clampedSpeed(speed) == speed)
        #expect(PrompterSettings.speedRange.contains(speed))
        #expect(SpeedScale.stops[SpeedScale.nearestStop(toSpeed: speed)] == multiple)
        #expect(SpeedScale.label(forSpeed: speed) == SpeedScale.label(forMultiple: multiple))
        let wordsPerMinute = PrompterSettings.wordsPerMinute(forSpeed: speed)
        #expect(abs(wordsPerMinute - wordsPerMinute.rounded()) < 0.000_001)
        #expect(Int(wordsPerMinute.rounded()) % 15 == 0)
    }

    @Test func oneTimesIsTheNaturalPace() {
        #expect(SpeedScale.speed(forMultiple: 1) == ReadTime.naturalSpeed)
        #expect(SpeedScale.nearestStop(toSpeed: ReadTime.naturalSpeed) == SpeedScale.defaultStop)
        #expect(PrompterSettings().speedLabel == "1×")
    }

    /// Whole numbers without a decimal point; tenths with the interface's separator ("0.2×" in English, "0,2×" in Portuguese).
    @Test func labelsHaveNoDecimalPointOnWholeNumbers() {
        let separator = Locale.interface.decimalSeparator ?? "."
        #expect(SpeedScale.label(forMultiple: 0.2) == "0\(separator)2×")
        #expect(SpeedScale.label(forMultiple: 1) == "1×")
        #expect(SpeedScale.label(forMultiple: 1.5) == "1\(separator)5×")
        #expect(SpeedScale.label(forMultiple: 2) == "2×")
    }

    /// A speed between two stops (saved by the 5-word steps of before) shows on the nearer one.
    @Test func aSpeedBetweenStopsShowsOnTheNearerOne() {
        let between = 155 / ReadTime.wordsPerMinuteAtOneX
        #expect(SpeedScale.stops[SpeedScale.nearestStop(toSpeed: between)] == 1)
        #expect(SpeedScale.nearestStop(toSpeed: 5) == SpeedScale.stops.count - 1)
        #expect(SpeedScale.nearestStop(toSpeed: 0) == 0)
    }

    @Test func steppingMovesOneStopAndHoldsAtTheEnds() {
        #expect(SpeedScale.speed(steppedBy: 1, fromSpeed: ReadTime.naturalSpeed) == SpeedScale.speed(forMultiple: 1.1))
        #expect(SpeedScale.speed(steppedBy: -1, fromSpeed: ReadTime.naturalSpeed) == SpeedScale.speed(forMultiple: 0.9))
        #expect(SpeedScale.speed(steppedBy: 1, fromSpeed: SpeedScale.fastestSpeed) == SpeedScale.fastestSpeed)
        #expect(SpeedScale.speed(steppedBy: -1, fromSpeed: SpeedScale.slowestSpeed) == SpeedScale.slowestSpeed)
    }
}
