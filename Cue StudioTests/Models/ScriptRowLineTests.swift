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

    /// The owner took the length, the cues and the topic off the list (30/10/2026): a ready script says only its platform.
    @Test func aReadyScriptSaysOnlyItsPlatform() {
        let script = TestData.script(text: "Hook. [pause] Body. [smile] More. [pause]", platform: .tiktok)
        #expect(ScriptRowLine(script: script, state: .ready, takes: [], hasDraft: { _ in false }).values == ["TikTok"])
    }

    @Test func aDraftShowsWhenItWasLastEditedAndABlankOneSaysSo() {
        let draft = TestData.script(text: "Some words", platform: .shorts, isFinished: false)
        let line = ScriptRowLine(script: draft, state: .draft, takes: [], hasDraft: { _ in false })
        #expect(line.values.count == 2 && line.values[0] == "Shorts")
        let blank = TestData.script(title: "", text: "", platform: .reels)
        #expect(ScriptRowLine(script: blank, state: .draft, takes: [], hasDraft: { _ in false }).values == ["Reels", "Blank"])
    }

    @Test func aRecordedScriptShowsItsTakesAndTheStageOfItsVideo() {
        let script = TestData.script(platform: .tiktok)
        let one = ScriptRowLine(script: script, state: .recorded, takes: [take(script)], hasDraft: { _ in false })
        #expect(one.values == ["TikTok", "1 take", "Ready"])
        let two = ScriptRowLine(script: script, state: .recorded, takes: [take(script), take(script)], hasDraft: { _ in false })
        #expect(two.values == ["TikTok", "2 takes", "To pick"])
        let edit = ScriptRowLine(script: script, state: .recorded, takes: [take(script, best: true)], hasDraft: { _ in true })
        #expect(edit.values.last == "In edit")
    }

    @Test func cuesAreCountedWithoutEmptyBrackets() {
        #expect(CueParser.count(in: "A [pause] b [] c [ ] d [look at camera]") == 2)
        #expect(CueParser.count(in: "No cues here.") == 0)
    }
}
