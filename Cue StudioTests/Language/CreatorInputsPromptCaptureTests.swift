//
//  CreatorInputsPromptCaptureTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

/// What each case of `CreatorInputsDeviceTests` sends to the model, on each route, kept as attachments (`creator-inputs-prompt-<case>-<route>-<idea>.txt`):
/// the instructions and the prompt as `ScriptAIService` builds them after `AIRequestPolicy.prepare`, before the on-device window check (which
/// leaves these small profiles alone) and before a second try that `VoiceCheckedWriting` may ask for.
@MainActor
struct CreatorInputsPromptCaptureTests {
    @Test(arguments: CreatorInputsDeviceTests.cases)
    func recordsWhatEachCaseSends(_ item: CreatorInputsDeviceTests.Case) {
        for route in [AIModelRoute.onDevice, .privateCloud] {
            for (index, idea) in item.ideas.enumerated() {
                let request = AIRequestPolicy.prepare(CreatorInputsDeviceTests.request(for: idea, item: item), on: route)
                let text = "ROUTE: \(route)\nLANGUAGE: \(request.language.map { "\($0)" } ?? "nil")\n\n=== INSTRUCTIONS ===\n"
                    + ScriptPromptBuilder.instructions(for: request) + "\n\n=== PROMPT ===\n" + ScriptPromptBuilder.prompt(for: request)
                #expect(!text.isEmpty)
                Attachment.record(Data(text.utf8), named: "creator-inputs-prompt-\(item.id)-\(route)-\(index).txt")
            }
        }
    }
}
