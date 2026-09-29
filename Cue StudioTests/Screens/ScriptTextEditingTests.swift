//
//  ScriptTextEditingTests.swift
//  Cue StudioTests
//

import Testing
@testable import Cue_Studio

@Suite("ScriptTextEditing")
struct ScriptTextEditingTests {
    @Test func replacesOnlyTheFirstParagraph() {
        let text = "\nOld hook.\nBody.\n\nClose."
        #expect(ScriptTextEditing.replacingOpening(of: text, with: "New hook.") == "\nNew hook.\nBody.\n\nClose.")
    }

    @Test func emptyTextBecomesTheHook() {
        #expect(ScriptTextEditing.replacingOpening(of: "  ", with: "Hook") == "Hook")
    }

    @Test func disclosureGoesUpFrontOnce() {
        let once = ScriptTextEditing.addingDisclosure(to: "Hello.")
        #expect(once.hasPrefix(ScriptTextEditing.disclosureLine(in: .english)))
        #expect(once == "[paid partnership] Quick heads-up: this video is sponsored.\n\nHello.")
        #expect(ScriptTextEditing.addingDisclosure(to: once) == once)
    }

    @Test func hookOptionsRotate() {
        let hooks = ["a", "b", "c", "d"]
        #expect(ScriptTextEditing.hookOptions(from: hooks, rotation: 0) == ["a", "b", "c"])
        #expect(ScriptTextEditing.hookOptions(from: hooks, rotation: 3) == ["d", "a", "b"])
    }
}
