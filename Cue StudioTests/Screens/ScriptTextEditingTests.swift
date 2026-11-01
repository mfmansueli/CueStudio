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
}
