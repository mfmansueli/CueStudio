//
//  ScriptRowLineTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

@Suite("ScriptRowLine")
struct ScriptRowLineTests {
    private func take(_ script: Script, best: Bool = false) -> Take {
        TestData.take(scriptID: script.id, isBest: best)
    }

    @Test func aReadyScriptShowsItsPlatformDurationAndCues() {
        let script = TestData.script(text: "Hook. [pause] Body. [smile] More. [pause]", platform: .tiktok)
        let line = ScriptRowLine(script: script, state: .ready, readSeconds: 47, takes: [], hasDraft: { _ in false })
        #expect(line.values == ["TikTok", "0:47", "3 cues"])
    }

    @Test func oneCueAndNoCuesAreSaidInTheSingular() {
        #expect(ScriptRowLine.cues(1) == "1 cue")
        #expect(ScriptRowLine.cues(0) == "No cues")
    }

    @Test func aDraftShowsWhenItWasLastEditedAndABlankOneSaysSo() {
        let draft = TestData.script(text: "Some words", platform: .shorts, isFinished: false)
        let line = ScriptRowLine(script: draft, state: .draft, readSeconds: 5, takes: [], hasDraft: { _ in false })
        #expect(line.values.count == 2 && line.values[0] == "Shorts")
        let blank = TestData.script(title: "", text: "", platform: .reels)
        #expect(ScriptRowLine(script: blank, state: .draft, readSeconds: 0, takes: [], hasDraft: { _ in false }).values == ["Reels", "Blank"])
    }

    @Test func aRecordedScriptShowsItsTakesAndTheStageOfItsVideo() {
        let script = TestData.script(platform: .tiktok)
        let one = ScriptRowLine(script: script, state: .recorded, readSeconds: 30, takes: [take(script)], hasDraft: { _ in false })
        #expect(one.values == ["TikTok", "1 take", "Ready"])
        let two = ScriptRowLine(script: script, state: .recorded, readSeconds: 30, takes: [take(script), take(script)], hasDraft: { _ in false })
        #expect(two.values == ["TikTok", "2 takes", "To pick"])
        let edit = ScriptRowLine(script: script, state: .recorded, readSeconds: 30, takes: [take(script, best: true)], hasDraft: { _ in true })
        #expect(edit.values.last == "In edit")
    }

    @Test func cuesAreCountedWithoutEmptyBrackets() {
        #expect(CueParser.count(in: "A [pause] b [] c [ ] d [look at camera]") == 2)
        #expect(CueParser.count(in: "No cues here.") == 0)
    }
}
