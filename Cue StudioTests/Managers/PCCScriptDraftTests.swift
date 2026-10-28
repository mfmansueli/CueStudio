import Testing
@testable import Cue_Studio

@Suite("Developed cloud draft")
struct PCCScriptDraftTests {
    @Test func developmentAndChecksRemainWithTheirOwnPointInSpeakingOrder() {
        let draft = PCCScriptDraft(
            title: "Window light", opening: "Use your window.", points: [
                .init(label: "Position", statement: "Face the window.", explanation: "It lights the face.", application: "Check the preview."),
                .init(label: "Diffuse", statement: "Use a sheer curtain.", explanation: "It softens direct light.", application: "Compare the shadows."),
            ], ending: "Adjust using the preview.", statesFacts: true
        ).scriptDraft
        #expect(draft.blocks[1].text == "Face the window. It lights the face. Check the preview.")
        #expect(draft.blocks[2].text == "Use a sheer curtain. It softens direct light. Compare the shadows.")
        #expect(draft.scriptText == "Use your window.\n\nFace the window. It lights the face. Check the preview.\n\nUse a sheer curtain. It softens direct light. Compare the shadows.\n\nAdjust using the preview.")
        #expect(!draft.scriptText.contains("Position"))
        #expect(draft.statesFacts)
    }

    @Test func aFactualNoticeNeedsNoInventedDevelopmentOrSignOff() {
        let draft = PCCScriptDraft(
            intent: .conciseStatement, title: "Correction", opening: "", points: [
                .init(
                    label: "Time", statement: "The correct time is 14:35.",
                    explanation: "Invented impact.", application: "Check an invented updated invitation."
                ),
            ], ending: "Invented commitment.", statesFacts: true
        ).scriptDraft
        #expect(draft.scriptText == "The correct time is 14:35.")
    }
}
