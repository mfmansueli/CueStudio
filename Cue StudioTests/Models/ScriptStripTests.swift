//
//  ScriptStripTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

/// The state strip (v29 · 4.1) in every state of 04 · F2: the switch or RECORDED, the one yellow line a changed recording has, and
/// whether the tools row offers "✦ Shape".
@Suite("Script strip")
struct ScriptStripTests {
    private func take(_ script: Script, number: Int, version: Int = 1) -> Take {
        var take = TestData.take(scriptID: script.id, number: number)
        take.scriptVersion = version
        return take
    }

    /// The owner took the line of details off the strip (31/10/2026): a ready script has its switch and nothing in words.
    @Test func aReadyScriptHasItsSwitchNoLineAndOffersShapeWhenThereAreNoCues() {
        let script = TestData.script(text: "Words with no cues at all.", type: .list)
        let strip = ScriptStrip(script: script, takes: [], hasAI: true, isEdited: false)
        #expect(strip.state == .ready)
        #expect(strip.signal == nil)
        #expect(strip.canShape && strip.showsReadySwitch && strip.isReady && !strip.recordsAgain)
    }

    @Test func shapeIsNotOfferedWithCuesOrWithoutAI() {
        let withCues = TestData.script(text: "Hook. [pause] Body. [smile]")
        #expect(!ScriptStrip(script: withCues, takes: [], hasAI: true, isEdited: false).canShape)
        #expect(ScriptStrip(script: withCues, takes: [], hasAI: true, isEdited: false).cueCount == 2)
        #expect(!ScriptStrip(script: TestData.script(text: ""), takes: [], hasAI: true, isEdited: false).canShape)
        let none = TestData.script(text: "No cues here.")
        #expect(!ScriptStrip(script: none, takes: [], hasAI: false, isEdited: false).canShape)
    }

    /// The switch, off, says it is a draft: no "Draft" beside it, edited or not.
    @Test func aDraftIsItsSwitchOffEditedOrNot() {
        let draft = TestData.script(text: "Some words", isFinished: false)
        for edited in [false, true] {
            let strip = ScriptStrip(script: draft, takes: [], hasAI: true, isEdited: edited)
            #expect(strip.state == .draft)
            #expect(strip.signal == nil)
            #expect(strip.showsReadySwitch && !strip.isReady)
        }
    }

    @Test func aRecordedScriptOffersRetakeAndNoDone() {
        let script = TestData.script(text: "Words", isFinished: false)
        let strip = ScriptStrip(script: script, takes: [take(script, number: 1)], hasAI: true, isEdited: false)
        #expect(strip.state == .recorded)
        #expect(!strip.showsReadySwitch && strip.recordsAgain)
        #expect(strip.signal == nil, "unchanged since its take: RECORDED says it all")
    }

    @Test func aRecordedScriptThatChangedSaysSoInYellow() {
        var script = TestData.script(text: "Words")
        script.version = 2
        let strip = ScriptStrip(script: script, takes: [take(script, number: 1), take(script, number: 3)], hasAI: true, isEdited: true)
        #expect(strip.changedSinceTake == 3)
        #expect(strip.signal == "Changed since take 3")
    }
}
