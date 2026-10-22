//
//  CueSliderSpecTests.swift
//  Cue StudioTests
//

import Testing
@testable import Cue_Studio

/// The slider table of `02-Tokens.md` §6: each range, step and default, held to the design.
@Suite("CueSliderSpec")
struct CueSliderSpecTests {
    /// One row of the table: a name, its spec and what the design says.
    fileprivate struct Row: CustomTestStringConvertible {
        let name: String
        let spec: CueSliderSpec
        let expected: CueSliderSpec
        var testDescription: String { name }
    }

    fileprivate static let rows = [
        Row(name: "speed", spec: .speed, expected: CueSliderSpec(30...300, step: 15, default: 150)),
        Row(name: "textSize", spec: .textSize, expected: CueSliderSpec(12...56, step: 1, default: 36)),
        Row(name: "readingLine", spec: .readingLine, expected: CueSliderSpec(10...50, step: 1, default: 22)),
        Row(name: "margins", spec: .margins, expected: CueSliderSpec(8...40, step: 2, default: 20)),
        Row(name: "textPoints", spec: .textPoints, expected: CueSliderSpec(24...120, step: 2, default: 64)),
        Row(name: "textGlow", spec: .textGlow, expected: CueSliderSpec(0...100, step: 5, default: 35)),
        Row(name: "voice", spec: .voice, expected: CueSliderSpec(0...200, step: 5, default: 100)),
        Row(name: "music", spec: .music, expected: CueSliderSpec(0...100, step: 5, default: 20)),
        Row(name: "clipSpeed", spec: .clipSpeed, expected: CueSliderSpec(0.5...3, step: 0.1, default: 1)),
        Row(name: "filterIntensity", spec: .filterIntensity, expected: CueSliderSpec(0...100, step: 1, default: 70)),
    ]

    @Test(arguments: rows)
    fileprivate func smoothControlsMatchTheTable(_ row: Row) {
        #expect(row.spec == row.expected, "\(row.name)")
        #expect(row.spec.range.contains(row.spec.defaultValue), "\(row.name) default is inside the range")
    }

    @Test func steppedControlsCountPositionsFromZero() {
        // S/M/L/XL (Large).
        #expect(CueSliderSpec.captionSize == .steps(4, default: 2))
        #expect(CueSliderSpec.captionSize.range == 0...3 && CueSliderSpec.captionSize.step == 1)
    }

    @Test func theDefaultsLandOnAStep() {
        for spec in [CueSliderSpec.speed, .textSize, .margins, .textPoints, .textGlow, .voice, .music, .clipSpeed, .filterIntensity] {
            let math = OrbSliderMath(range: spec.range, step: spec.step, defaultValue: spec.defaultValue)
            #expect(math.snapped(spec.defaultValue) == spec.defaultValue, "\(spec)")
        }
    }

    @Test func theNaturalPaceIsTheSpeedDefault() {
        #expect(ReadTime.wordsPerMinute(speed: ReadTime.naturalSpeed).rounded() == CueSliderSpec.speed.defaultValue)
    }

    /// The table's speed is the prompter's: its ends are the range's, and its step is one stop of `SpeedScale`.
    @Test func theSpeedRowIsThePrompterScale() {
        #expect(ReadTime.wordsPerMinute(speed: PrompterSettings.speedRange.lowerBound).rounded() == CueSliderSpec.speed.range.lowerBound)
        #expect(ReadTime.wordsPerMinute(speed: PrompterSettings.speedRange.upperBound).rounded() == CueSliderSpec.speed.range.upperBound)
        #expect(CueSliderSpec.speed.step == SpeedScale.wordsPerMinuteAtOneX / 10)
        #expect(CueSliderSpec.textSize.range == PrompterSettings.sizeRange)
    }
}
