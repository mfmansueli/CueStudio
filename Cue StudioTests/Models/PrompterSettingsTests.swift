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
        // Same pace on the new scale: 1.4 × 150 ÷ 215 ≈ 1.0.
        #expect(settings.speed == 1)
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
        #expect(!settings.hidesControlsWhileRecording)
    }

    @Test func startsAtTheNaturalSpeed() {
        #expect(PrompterSettings().speed == 0.7)
    }

    @Test func startsWithTheWidestTallestWindowAndTheCoachOff() {
        let settings = PrompterSettings()
        #expect(settings.readingWidth == PrompterSettings.readingWidthRange.upperBound)
        #expect(settings.textWindowHeight == PrompterSettings.textWindowHeightRange.upperBound)
        #expect(!settings.showsCues)
    }

    @Test(arguments: [(1.0, 0.7), (0.5, 0.3), (2.0, 1.4), (3.0, 2.0)])
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

    @Test func clampedSpeedStepsInTenthsWithinTheRange() {
        #expect(PrompterSettings.clampedSpeed(0.74) == 0.7)
        #expect(PrompterSettings.clampedSpeed(0.1) == 0.3)
        #expect(PrompterSettings.clampedSpeed(2.4) == 2)
    }

    @Test func marginsAboveTheNewRangeAreClamped() throws {
        let settings = try JSONDecoder().decode(PrompterSettings.self, from: Data(#"{"margin":64}"#.utf8))
        #expect(settings.margin == 32)
    }

    @Test func roundTrips() throws {
        var settings = PrompterSettings()
        settings.readingWidth = 0.7
        settings.cameraBlur = 9
        settings.textWindowHeight = 320
        settings.readingLineOffset = 140
        settings.customSafeZone.bottom = 30
        settings.hidesControlsWhileRecording = true
        let decoded = try JSONDecoder().decode(PrompterSettings.self, from: JSONEncoder().encode(settings))
        #expect(decoded == settings)
    }

    @Test(arguments: [(0.0, "Off"), (4.0, "Subtle"), (10.0, "Soft"), (20.0, "Medium")])
    func cameraBlurHasFourGentleLevels(_ amount: Double, _ label: String) {
        var settings = PrompterSettings()
        settings.cameraBlur = amount
        #expect(settings.cameraBlurLabel == label)
        #expect(CameraBlurLevel(amount: amount).strength < 1)
    }
}
