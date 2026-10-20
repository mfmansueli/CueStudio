//
//  EyeContactStateTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

/// What Eye Contact says: "On" only as a setting, how much is corrected once it's known, never "done" while only part is ready.
@Suite("EyeContactState")
struct EyeContactStateTests {
    @Test func offSaysNothing() {
        #expect(EyeContactState.off.note == nil)
        #expect(EyeContactState.off.tileStatus == nil)
    }

    @Test func workingSaysHowFarAndOffersCancel() {
        let state = EyeContactState.preparing(0.42, readyHere: false)
        #expect(state.isWorking)
        #expect(state.note?.contains("42") == true)
        let here = EyeContactState.preparing(0.42, readyHere: true)
        #expect(here.note != state.note)
        #expect(EyeContactState.paused(.heat, 0.1).isWorking)
    }

    @Test func readyTellsTheShareCorrectedNotDone() {
        let state = EyeContactState.ready(0.87)
        #expect(!state.isWorking)
        #expect(state.note?.contains("87") == true)
        #expect(state.tileStatus == String(localized: "On"))
    }

    @Test func percentNeverOverstates() {
        #expect(EyeContactState.percent(0) == 0)
        #expect(EyeContactState.percent(0.001) == 1)
        #expect(EyeContactState.percent(0.999) == 99)
        #expect(EyeContactState.percent(1) == 100)
    }

    @Test func nothingToCorrectSaysWhy() {
        #expect(EyeContactState.nothingToCorrect(.otherPeople).note != EyeContactState.nothingToCorrect(nil).note)
        #expect(EyeContactState.nothingToCorrect(.smallEyes).tileStatus == String(localized: "No face"))
    }
}
