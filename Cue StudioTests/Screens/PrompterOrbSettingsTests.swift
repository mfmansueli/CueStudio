//
//  PrompterOrbSettingsTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

/// Settings › Prompter as orbs: four text sizes, three reading-line places, three margins, the countdown and
/// "Follow my voice".
@MainActor
@Suite("Prompter orb settings")
struct PrompterOrbSettingsTests {
    private func make() -> (CreatorSetupViewModel, PreferencesService, TestDefaults) {
        let defaults = TestDefaults()
        let preferences = PreferencesService(defaults: defaults.defaults)
        return (CreatorSetupViewModel(preferences: preferences, microphones: FakeMicrophones(), toast: ToastService()), preferences, defaults)
    }

    @Test func textSizeHasFourStepsAndAMediumDefault() {
        let (model, preferences, defaults) = make()
        defer { defaults.tearDown() }
        #expect(model.textSizeStep == 1 && model.textSizeLabel == "Medium")
        model.textSizeStep = 3
        #expect(preferences.prompter.size == 48 && model.textSizeLabel == "Extra large")
        model.textSizeStep = 0
        #expect(preferences.prompter.size == 22)
    }

    @Test func aSizeSetInDisplayLandsOnTheNearestStep() {
        let (model, _, defaults) = make()
        defer { defaults.tearDown() }
        model.textSize = 40
        #expect(model.textSizeStep == 2)
        model.textSize = 17
        #expect(model.textSizeStep == 0)
    }

    @Test func theReadingLineHasThreePlacesAndAHandMovedLineMatchesNone() {
        let (model, _, defaults) = make()
        defer { defaults.tearDown() }
        #expect(model.readingLineStep == 0)
        model.readingLineStep = 2
        #expect(ReadingLinePreset(model.setup.readingLine) == .middle)
        model.readingLineStep = 0
        #expect(model.isReadingLineRecommended)
        model.nudgeReadingLine(by: 40)
        #expect(ReadingLinePreset(model.setup.readingLine) == nil)
    }

    @Test func marginsAreNarrowMediumOrWideAroundTheDefault() {
        let (model, preferences, defaults) = make()
        defer { defaults.tearDown() }
        #expect(model.marginStep == 1)
        model.marginStep = 2
        #expect(preferences.prompter.margin == MarginPreset.wide.points)
        preferences.prompter.margin = 3
        #expect(model.marginStep == 0, "a margin set in Display lands on the nearest")
    }

    @Test func theCountdownMovesAlongOffThreeFiveTen() {
        let (model, preferences, defaults) = make()
        defer { defaults.tearDown() }
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

    @Test func speedIsShownInWordsAMinute() {
        let (model, _, defaults) = make()
        defer { defaults.tearDown() }
        model.speed = 1.0
        #expect(model.wordsPerMinute == Int(ReadTime.wordsPerMinuteAtOneX.rounded()))
    }
}
