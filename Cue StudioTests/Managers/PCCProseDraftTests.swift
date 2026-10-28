import Testing
@testable import Cue_Studio

@Suite("Cloud prose experiment")
struct PCCProseDraftTests {
    @Test func keepsTheWholeSpokenSceneWithoutIntroducingPointLabels() {
        let text = "Pulso grabar.\n\nEl gato se sienta frente a la cámara.\n\nSigo mezclando."
        let draft = PCCProseDraft(intent: .developed, title: "Una toma", text: text, statesFacts: false).scriptDraft
        #expect(draft.scriptText == text)
        #expect(draft.blocks.count == 1 && draft.title == "Una toma")
        #expect(!draft.statesFacts)
    }

    @Test func aShortCorrectionKeepsItsFactsAndExactWording() {
        let text = "Publicamos el horario equivocado. El correcto es 14:35."
        let draft = PCCProseDraft(intent: .conciseStatement, title: "Corrección", text: text, statesFacts: true).scriptDraft
        #expect(draft.scriptText == text)
        #expect(draft.statesFacts)
    }
}
