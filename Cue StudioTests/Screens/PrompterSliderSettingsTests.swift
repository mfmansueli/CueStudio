//
//  PrompterSliderSettingsTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

/// Settings › Prompter as sliders (v29 ranges): speed in words a minute, four text sizes, the reading line as a
/// percent of the screen, margins in points, the countdown and "Follow my voice".
@MainActor
@Suite("Prompter slider settings")
struct PrompterSliderSettingsTests {
    private func make() -> (CreatorSetupViewModel, PreferencesService, TestDefaults) {
        let defaults = TestDefaults()
        let preferences = PreferencesService(defaults: defaults.defaults)
        return (CreatorSetupViewModel(preferences: preferences, microphones: FakeMicrophones(), toast: ToastService()), preferences, defaults)
    }

    @Test func textSizeHasFourStepsAndALargeDefault() {
        let (model, preferences, defaults) = make()
        defer { defaults.tearDown() }
        #expect(model.textSizeStep == 2 && model.textSizeLabel == "Large")
        #expect(model.textSizeStep == CueSliderSpec.textSize.defaultValue)
        model.textSizeStep = 3
        #expect(preferences.prompter.size == 44 && model.textSizeLabel == "Extra large")
        model.textSizeStep = 0
        #expect(preferences.prompter.size == 24)
        #expect([0, 1, 2, 3].map { PrompterTextSize.allCases[$0].points } == [24, 30, 36, 44])
    }

    @Test func aSizeSetInDisplayLandsOnTheNearestStep() {
        let (model, _, defaults) = make()
        defer { defaults.tearDown() }
        model.textSize = 40
        #expect(model.textSizeStep == 2)
        model.textSize = 17
        #expect(model.textSizeStep == 0)
    }

    @Test func theReadingLineIsAPercentOfTheScreenAndRecommendedShowsWhereItSits() {
        let (model, _, defaults) = make()
        defer { defaults.tearDown() }
        model.screenScale = ReadingLinePercent(screenHeight: 800, lensY: 30)
        #expect(model.isReadingLineRecommended)
        // 118 pt under a lens 30 pt down, on 800 pt: 18.5% → 19%.
        #expect(model.readingLinePercent == 19)
        model.readingLinePercent = 50
        #expect(model.setup.readingLine == .offset(370))
        #expect(model.readingLinePercent == 50)
        model.readingLinePercent = 10
        #expect(model.setup.readingLine == .offset(50))
        model.resetReadingLine()
        #expect(model.isReadingLineRecommended)
    }

    @Test func marginsRunFromEightToFortyPoints() {
        let (model, preferences, defaults) = make()
        defer { defaults.tearDown() }
        #expect(model.marginPoints == CueSliderSpec.margins.defaultValue)
        model.marginPoints = 40
        #expect(preferences.prompter.margin == 40)
        model.marginPoints = 2
        #expect(preferences.prompter.margin == 8, "held to the range")
    }

    @Test func theCountdownMovesAlongOffThreeFiveTen() {
        let (model, preferences, defaults) = make()
        defer { defaults.tearDown() }
        #expect(CueSliderSpec.countdown.defaultValue == 1 && Countdown.allCases[1] == .three)
        model.countdownStep = 3
        #expect(preferences.camera.countdown == .ten)
        model.countdownStep = 0
        #expect(preferences.camera.countdown == .off)
        #expect(model.countdownStep == 0)
    }

    @Test func followMyVoiceIsTheVoiceReadingMode() {
        let (model, preferences, defaults) = make()
        defer { defaults.tearDown() }
        #expect(!model.followsVoice)
        model.followsVoice = true
        #expect(preferences.prompter.scrollMode == .voice)
        model.followsVoice = false
        #expect(preferences.prompter.scrollMode == .steady)
    }

    @Test func speedIsInWordsAMinuteInStepsOfFive() {
        let (model, _, defaults) = make()
        defer { defaults.tearDown() }
        #expect(model.wordsPerMinuteValue == 150, "the natural pace is a step of the slider")
        model.wordsPerMinuteValue = 175
        #expect(model.wordsPerMinute == 175)
        model.wordsPerMinuteValue = 177
        #expect(model.wordsPerMinute == 175, "held on the step")
        model.speed = 1.0
        #expect(model.wordsPerMinute == Int(ReadTime.wordsPerMinuteAtOneX.rounded()))
    }
}
