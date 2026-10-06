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

    // 1.0× meant 150 words a minute before the scale changed; the pace is kept on the 5 wpm step nearest it.
    @Test(arguments: [(1.0, 150.0 / 215), (0.5, 75.0 / 215), (2.0, 300.0 / 215), (3.0, 2.0)])
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
        #expect(PrompterSettings.clampedSpeed(0.1) == 0.3)
        #expect(PrompterSettings.clampedSpeed(2.4) == 2)
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
