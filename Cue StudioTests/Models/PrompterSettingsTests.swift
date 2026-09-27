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
        #expect(settings.speed == 1.4)
        #expect(settings.font == .legible)
        #expect(settings.size == 40)
        #expect(settings.scrollMode == .voice)
        #expect(!settings.showsCues)
        #expect(settings.margin == 24)
        #expect(settings.backgroundOpacity == 0.25)
        #expect(settings.readingWidth == 0.6)
        #expect(settings.cameraBlur == 0)
    }

    @Test func marginsAboveTheNewRangeAreClamped() throws {
        let settings = try JSONDecoder().decode(PrompterSettings.self, from: Data(#"{"margin":64}"#.utf8))
        #expect(settings.margin == 32)
    }

    @Test func roundTrips() throws {
        var settings = PrompterSettings()
        settings.readingWidth = 0.7
        settings.cameraBlur = 9
        let decoded = try JSONDecoder().decode(PrompterSettings.self, from: JSONEncoder().encode(settings))
        #expect(decoded == settings)
    }

    @Test(arguments: [(0.0, "Off"), (4.0, "Low"), (10.0, "Medium"), (20.0, "High")])
    func cameraBlurHasFourLevels(_ amount: Double, _ label: String) {
        var settings = PrompterSettings()
        settings.cameraBlur = amount
        #expect(settings.cameraBlurLabel == label)
    }
}
