//
//  PCCEditorialDemonstrationTests.swift
//  Cue StudioTests
//

import FoundationModels
import Testing
@testable import Cue_Studio

@MainActor
@Suite("Editorial demonstration isolation")
struct PCCEditorialDemonstrationTests {
    @Test func keepsASyntheticConversationOutsideTheEvaluatedRequests() throws {
        let cases = try ScriptIntentCase.load()
        #expect(!cases.contains { $0.prompt == PCCEditorialDemonstration.request })
        let transcript = PCCEditorialDemonstration.transcript(instructions: "CURRENT_INSTRUCTIONS")
        #expect(transcript.count == 3)
        guard case .instructions(let instructions) = transcript[0], case .prompt(let prompt) = transcript[1],
              case .response(let response) = transcript[2] else {
            Issue.record("The demonstration must use actual instructions/user/assistant roles")
            return
        }
        guard case .text(let text)? = instructions.segments.first else {
            Issue.record("The instruction entry must retain its text")
            return
        }
        #expect(text.content == "CURRENT_INSTRUCTIONS")
        #expect(prompt.segments.count == 1 && response.segments.count == 1)
        #expect(PCCEditorialDemonstration.auditText.contains(PCCEditorialDemonstration.request))
        #expect(PCCEditorialDemonstration.auditText.contains(PCCEditorialDemonstration.response))
        #expect(!PCCEditorialDemonstration.response.contains("roteiro"))
    }

    @Test func editorialFrameChangesOnlyInstructionsAndKeepsTheCreatorsInputs() {
        var request = ScriptRequest(
            source: .prompt("Explain this idea in my voice"), platform: .reels, voice: nil,
            targetRange: 60...90, language: .english
        )
        request.durationPolicy = .informative
        let lean = PCCEditorialExperimentPrompt(request: request)
        let editorial = PCCEditorialExperimentPrompt(request: request, editorial: true)
        #expect(lean.prompt == editorial.prompt)
        #expect(lean.instructions != editorial.instructions)
        #expect(editorial.instructions.contains("metaphors cannot replace the argument"))
        #expect(editorial.instructions.contains("English"))
    }
}
