//
//  PrompterSettingsTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

@Suite("PrompterSettings")
struct PrompterSettingsTests {
    @Test func v1SettingsKeepFontSizeAndSpeed() throws {
        let v1 = """
        {"speed":1.4,"font":"legible","size":40,"lineSpacing":1.5,"alignment":"left","textColor":"#FFD60A",
         "margin":24,"dim":0.5,"showsGuide":true,"guidePosition":0.4,"isMirrored":false,"scrollMode":"voice",
         "studioBackground":"#1C1C1E","showsCues":false}
        """
        let settings = try JSONDecoder().decode(PrompterSettings.self, from: Data(v1.utf8))
        // Same pace on the new scale: 1.4 × 150 = 210 words a minute.
        #expect(settings.speed == 210.0 / 215)
        #expect(settings.font == .legible)
        #expect(settings.size == 40)
        #expect(settings.scrollMode == .voice)
        #expect(!settings.showsCues)
        #expect(settings.margin == 24)
        #expect(settings.backgroundOpacity == 0.25)
        #expect(settings.readingWidth == 0.93)
        #expect(settings.cameraBlur == 0)
        #expect(settings.textWindowHeight == 380)
        #expect(settings.readingLineOffset == nil)
        #expect(settings.customSafeZone == SafeZoneMargins())
    }

    @Test func startsAtTheNaturalSpeed() {
        #expect(PrompterSettings().speed == ReadTime.naturalSpeed)
    }

    @Test func startsWithTheOriginalWindowAndTheCoachOff() {
        let settings = PrompterSettings()
        #expect(settings.readingWidth == PrompterSettings.defaultReadingWidth)
        #expect(settings.textWindowHeight == PrompterSettings.defaultTextWindowHeight)
        #expect(PrompterSettings.readingWidthRange.contains(settings.readingWidth))
        #expect(PrompterSettings.textWindowHeightRange.contains(settings.textWindowHeight))
        #expect(!settings.showsCues)
    }

    @Test func settingsSavedBeforeTheRigsAndSafeZoneRowsDecodeWithThemOff() throws {
        let settings = try JSONDecoder().decode(PrompterSettings.self, from: Data(#"{"size":36,"isMirrored":true}"#.utf8))
        #expect(settings.isMirrored)
        #expect(!settings.isFlippedVertically)
        #expect(settings.safeZoneKey == nil)
    }

    @Test func flipAndTheSafeZoneChoiceAreSaved() throws {
        var settings = PrompterSettings()
        settings.isFlippedVertically = true
        settings.safeZoneKey = SafeZoneChoice.custom.key
        let decoded = try JSONDecoder().decode(PrompterSettings.self, from: JSONEncoder().encode(settings))
        #expect(decoded.isFlippedVertically)
        #expect(decoded.safeZoneKey == "custom")
    }

    /// New York keeps the raw value "serif" the serif choice was saved with.
    @Test func theSerifChoiceOfBeforeIsNewYork() throws {
        let settings = try JSONDecoder().decode(PrompterSettings.self, from: Data(#"{"font":"serif"}"#.utf8))
        #expect(settings.font == .newYork)
        #expect(PrompterFont.allCases.map(\.label) == ["SF Pro", "New York", "SF Rounded", "Lexend", "Atkinson Hyperlegible"])
    }

    // 1.0× meant 150 words a minute before the scale changed; the pace is kept on the 5 wpm step nearest it, held to 2× (300).
    @Test(arguments: [(1.0, 150.0 / 215), (0.5, 75.0 / 215), (2.0, 300.0 / 215), (6.0, 300.0 / 215)] as [(Double, Double)])
    func speedsSavedBeforeTheNewScaleKeepTheirPace(_ saved: Double, _ expected: Double) throws {
        let settings = try JSONDecoder().decode(PrompterSettings.self, from: Data(#"{"speed":\#(saved)}"#.utf8))
        #expect(settings.speed == expected)
    }

    @Test func speedsSavedOnTheNewScaleStayPut() throws {
        var settings = PrompterSettings()
        settings.speed = 1.3
        let decoded = try JSONDecoder().decode(PrompterSettings.self, from: JSONEncoder().encode(settings))
        #expect(decoded.speed == 1.3)
    }

    @Test func clampedSpeedStepsInFiveWordsAMinuteWithinTheRange() {
        // 0.74× is 159 words a minute: the step of 5 nearest is 160.
        #expect(PrompterSettings.clampedSpeed(0.74) == 160 / ReadTime.wordsPerMinuteAtOneX)
        #expect(PrompterSettings.clampedSpeed(0.1) == 30 / ReadTime.wordsPerMinuteAtOneX)
        #expect(PrompterSettings.clampedSpeed(4) == 300 / ReadTime.wordsPerMinuteAtOneX)
    }

    /// The range is the speed scale's ends, 0.2× and 2×: 30 and 300 words a minute.
    @Test func theSpeedRangeIsTheScalesEnds() {
        #expect(PrompterSettings.speedRange.lowerBound == SpeedScale.speed(forMultiple: 0.2))
        #expect(PrompterSettings.speedRange.upperBound == SpeedScale.speed(forMultiple: 2))
        #expect(PrompterSettings.wordsPerMinute(forSpeed: PrompterSettings.speedRange.lowerBound).rounded() == 30)
        #expect(PrompterSettings.wordsPerMinute(forSpeed: PrompterSettings.speedRange.upperBound).rounded() == 300)
    }

    /// The 3×, 4× and 5× the slider had before 20/10/2026 open on 2×; a speed inside the range opens as it was saved.
    @Test(arguments: [(3.0, 2.0), (4.0, 2.0), (5.0, 2.0), (2.0, 2.0), (1.5, 1.5), (0.5, 0.5)] as [(Double, Double)])
    func speedsSavedPastTheFastestStopOpenOnIt(_ savedMultiple: Double, _ expectedMultiple: Double) throws {
        let saved = Data(#"{"speed":\#(savedMultiple * 150 / 215),"speedCalibration":215}"#.utf8)
        let settings = try JSONDecoder().decode(PrompterSettings.self, from: saved)
        #expect(abs(SpeedScale.multiple(forSpeed: settings.speed) - expectedMultiple) < 0.000_001)
        #expect(settings.speedLabel == SpeedScale.label(forMultiple: expectedMultiple))
    }

    /// Sizes are held to 12…56 points: anything saved outside opens on the nearest end, and the new small sizes are kept.
    @Test(arguments: [(12.0, 12.0), (14.0, 14.0), (8.0, 12.0), (80.0, 56.0), (36.0, 36.0)] as [(Double, Double)])
    func sizesOpenInsideTheRange(_ saved: Double, _ expected: Double) throws {
        let settings = try JSONDecoder().decode(PrompterSettings.self, from: Data(#"{"size":\#(saved)}"#.utf8))
        #expect(settings.size == expected)
    }

    @Test func marginsAboveTheNewRangeAreClamped() throws {
        let settings = try JSONDecoder().decode(PrompterSettings.self, from: Data(#"{"margin":64}"#.utf8))
        #expect(settings.margin == 40)
    }

    @Test func roundTrips() throws {
        var settings = PrompterSettings()
        settings.readingWidth = 0.7
        settings.cameraBlur = 9
        settings.textWindowHeight = 320
        settings.readingLineOffset = 140
        settings.customSafeZone.bottom = 30
        let decoded = try JSONDecoder().decode(PrompterSettings.self, from: JSONEncoder().encode(settings))
        #expect(decoded == settings)
    }

    /// "Hide controls while recording" is gone: settings saved while it existed still load, with
    /// everything else kept, and the old key is not written back.
    @Test func settingsSavedWithTheRemovedHideControlsKeyStillLoad() throws {
        let saved = Data(#"{"size":40,"readingWidth":0.7,"hidesControlsWhileRecording":true}"#.utf8)
        let decoded = try JSONDecoder().decode(PrompterSettings.self, from: saved)
        #expect(decoded.size == 40)
        #expect(decoded.readingWidth == 0.7)
        let rewritten = try #require(String(data: JSONEncoder().encode(decoded), encoding: .utf8))
        #expect(!rewritten.contains("hidesControlsWhileRecording"))
    }

    @Test(arguments: [(0.0, "Off"), (4.0, "Subtle"), (10.0, "Soft"), (20.0, "Medium")])
    func cameraBlurHasFourGentleLevels(_ amount: Double, _ label: String) {
        var settings = PrompterSettings()
        settings.cameraBlur = amount
        #expect(settings.cameraBlurLabel == label)
        #expect(CameraBlurLevel(amount: amount).strength < 1)
    }
}
