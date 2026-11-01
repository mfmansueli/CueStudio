//
//  ScriptTextEditingTests.swift
//  Cue StudioTests
//

import Testing
@testable import Cue_Studio

@Suite("ScriptTextEditing")
struct ScriptTextEditingTests {
    @Test func disclosureGoesUpFrontOnce() {
        let once = ScriptTextEditing.addingDisclosure(to: "Hello.")
        #expect(once.hasPrefix(ScriptTextEditing.disclosureLine(in: .english)))
        #expect(once == "[paid partnership] Quick heads-up: this video is sponsored.\n\nHello.")
        #expect(ScriptTextEditing.addingDisclosure(to: once) == once)
    }

    @Test(arguments: [
        "Ich habe es ausprobiert.\n\n[paid partnership] Kurzer Hinweis: Dieses Video ist gesponsert.",
        "Kurzer Hinweis: Dieses Video ist gesponsert.\n\nIch habe es ausprobiert.",
        "Probei por um mês. #publi",
        "I tried it for a month. #ad",
    ])
    func aScriptAlreadyDisclosedAnywhereIsNotDisclosedAgain(_ text: String) {
        #expect(ScriptTextEditing.hasDisclosure(text))
        #expect(ScriptTextEditing.addingDisclosure(to: text) == text)
    }

    @Test func wordsThatOnlyLookLikeATagAreNotADisclosure() {
        #expect(!ScriptTextEditing.hasDisclosure("I read the #adventure books. Add a pub quiz."))
    }

    @Test func hookOptionsRotate() {
        let hooks = ["a", "b", "c", "d"]
        #expect(ScriptTextEditing.hookOptions(from: hooks, rotation: 0) == ["a", "b", "c"])
        #expect(ScriptTextEditing.hookOptions(from: hooks, rotation: 3) == ["d", "a", "b"])
    }

    /// A hook Cue offers is never one its own tip calls long; where too few fit, the shortest of the rest make up three.
    @Test func hookOptionsLeaveOutTheOnesTheTipWouldCallLong() {
        let long = "This opening line takes far longer than a few seconds to say out loud."
        #expect(!ScriptTextEditing.hookOptions(from: ["a b", long, "c d", "e f"], rotation: 0).contains(long))
        let longer = long + " And then some more."
        #expect(ScriptTextEditing.hookOptions(from: ["a b", longer, long], rotation: 0) == ["a b", long, longer])
    }

    /// Every ready-made hook of every format, in English, is said within the hook's few seconds (the translations are measured the same way
    /// when they are offered: `hookOptions`).
    @Test(arguments: [nil] + ScriptType.allCases.map(Optional.some))
    func everyReadyMadeHookIsShortInEnglish(_ type: ScriptType?) {
        let hooks = type?.structure(hooksIn: .english).hooks ?? ScriptStructure.generic(hooksIn: .english).hooks
        for hook in hooks {
            #expect(ReadTime.seconds(for: hook) <= ScriptBlocks.hookTarget, "\(hook) runs \(ReadTime.seconds(for: hook)) s")
        }
    }
}
