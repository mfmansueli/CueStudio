//
//  ScriptStripTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

/// The state strip (v29 · 4.1) in every state of 04 · F2.
@Suite("Script strip")
struct ScriptStripTests {
    private func take(_ script: Script, number: Int, version: Int = 1) -> Take {
        var take = TestData.take(scriptID: script.id, number: number)
        take.scriptVersion = version
        return take
    }

    @Test func aReadyScriptShowsItsFormatAndCuesAndOffersShapeWhenThereAreNone() {
        let script = TestData.script(text: "Words with no cues at all.", type: .list)
        let strip = ScriptStrip(script: script, takes: [], hasAI: true, isEdited: false)
        #expect(strip.state == .ready)
        #expect(strip.info == ["Tips / list", "No cues"])
        #expect(strip.canShape && strip.showsReadySwitch && strip.isReady && !strip.recordsAgain && strip.recordIsPrimary)
    }

    @Test func shapeIsNotOfferedWithCuesOrWithoutAI() {
        let withCues = TestData.script(text: "Hook. [pause] Body. [smile]")
        #expect(!ScriptStrip(script: withCues, takes: [], hasAI: true, isEdited: false).canShape)
        #expect(ScriptStrip(script: withCues, takes: [], hasAI: true, isEdited: false).info.last == "2 cues")
        let none = TestData.script(text: "No cues here.")
        #expect(!ScriptStrip(script: none, takes: [], hasAI: false, isEdited: false).canShape)
    }

    @Test func aDraftSaysSoBesideItsSwitchEditedOrNot() {
        let draft = TestData.script(text: "Some words", isFinished: false)
        for edited in [false, true] {
            let strip = ScriptStrip(script: draft, takes: [], hasAI: true, isEdited: edited)
            #expect(strip.state == .draft)
            #expect(strip.info == ["Draft", "Your script", "No cues"])
            #expect(strip.showsReadySwitch && !strip.isReady)
        }
    }

    @Test func aScriptWithNoFormatSaysYourScript() {
        let strip = ScriptStrip(script: TestData.script(text: "Hi [pause]"), takes: [], hasAI: true, isEdited: false)
        #expect(strip.info == ["Your script", "1 cue"])
    }

    @Test func aRecordedScriptOffersRetakeAndNoDone() {
        let script = TestData.script(text: "Words", isFinished: false)
        let strip = ScriptStrip(script: script, takes: [take(script, number: 1)], hasAI: true, isEdited: false)
        #expect(strip.state == .recorded)
        #expect(!strip.showsReadySwitch && strip.recordsAgain)
        #expect(!strip.recordIsPrimary, "unchanged since its take: the record button stays quiet")
        #expect(!strip.isSignal)
    }

    @Test func aRecordedScriptThatChangedSaysSoInYellowAndRetakeBecomesThePrimary() {
        var script = TestData.script(text: "Words")
        script.version = 2
        let strip = ScriptStrip(script: script, takes: [take(script, number: 1), take(script, number: 3)], hasAI: true, isEdited: true)
        #expect(strip.changedSinceTake == 3)
        #expect(strip.info == ["Changed since take 3"])
        #expect(strip.isSignal && strip.recordIsPrimary)
    }
}
