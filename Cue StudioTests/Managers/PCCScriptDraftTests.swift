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

    @Test func aSceneKeepsTheEventsAndDropsExplanatoryCoaching() {
        let draft = PCCScriptDraft(
            intent: .fictionalScene, title: "The cat", opening: "I press record.", points: [
                .init(label: "Unwanted coaching", statement: "Try moving the camera.",
                      explanation: "This builds tension.", application: "Use a higher tripod."),
            ], sceneBeats: [
                .init(moment: "My cat sits in front of the lens.", response: "I stop with the bowl in my hands."),
                .init(moment: "I lift the phone.", response: "The cat follows it with his eyes."),
            ], ending: "I start mixing anyway.", statesFacts: false
        ).scriptDraft
        #expect(draft.scriptText == "I press record.\n\nMy cat sits in front of the lens. I stop with the bowl in my hands.\n\nI lift the phone. The cat follows it with his eyes.\n\nI start mixing anyway.")
        #expect(!draft.scriptText.contains("Try moving") && !draft.scriptText.contains("This builds tension"))
    }

}
