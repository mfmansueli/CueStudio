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
        Row(name: "speed", spec: .speed, expected: CueSliderSpec(80...220, step: 5, default: 150)),
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
        // S/M/L/XL (Large), Off/3/5/10 s (3 s), Off/Soft/Full (Full), Off/Light/Strong (Light).
        #expect(CueSliderSpec.textSize == .steps(4, default: 2))
        #expect(CueSliderSpec.captionSize == .steps(4, default: 2))
        #expect(CueSliderSpec.countdown == .steps(4, default: 1))
        #expect(CueSliderSpec.starrySky == .steps(3, default: 2))
        #expect(CueSliderSpec.cleanUpVoice == .steps(3, default: 1))
        #expect(CueSliderSpec.textSize.range == 0...3 && CueSliderSpec.textSize.step == 1)
    }

    @Test func theDefaultsLandOnAStep() {
        for spec in [CueSliderSpec.speed, .margins, .textPoints, .textGlow, .voice, .music, .clipSpeed, .filterIntensity] {
            let math = OrbSliderMath(range: spec.range, step: spec.step, defaultValue: spec.defaultValue)
            #expect(math.snapped(spec.defaultValue) == spec.defaultValue, "\(spec)")
        }
    }

    @Test func theNaturalPaceIsTheSpeedDefault() {
        #expect(PrompterSettings.wordsPerMinute(forSpeed: ReadTime.naturalSpeed) == CueSliderSpec.speed.defaultValue)
        #expect(PrompterSettings.speed(forWordsPerMinute: 150) == ReadTime.naturalSpeed)
    }

    @Test func wordsAMinuteConvertToAStoredSpeedOnTheStep() {
        let speed = PrompterSettings.speed(forWordsPerMinute: 177)
        #expect(PrompterSettings.wordsPerMinute(forSpeed: speed).rounded() == 175)
        #expect(PrompterSettings.speed(forWordsPerMinute: 5000) == PrompterSettings.speedRange.upperBound)
    }
}
