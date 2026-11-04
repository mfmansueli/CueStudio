//
//  IdeaTitleTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

/// A script from an idea keeps the idea's title on Apple Intelligence too (`ScriptRequest.ideaTitle`); a typed request keeps the model's.
@MainActor
struct IdeaTitleTests {
    private let draft = ScriptDraft(
        title: "Water bottles",
        blocks: [ScriptDraft.Block(label: "Hook", text: "I stopped buying bottled water a year ago.")],
        statesFacts: false
    )
    private let timings = GenerationTimings(prepare: .zero, firstResponse: nil, generation: .zero)

    private func request(brief: IdeaBrief? = nil) -> ScriptRequest {
        var request = ScriptRequest(source: .prompt("Why I stopped buying bottled water"), platform: .tiktok, voice: nil, targetRange: 60...90)
        request.language = .english
        request.brief = brief
        return request
    }

    @Test func aScriptFromAnIdeaKeepsTheIdeasTitleWhateverItsLength() throws {
        let long = "The day I stopped buying bottled water and what it did to my monthly budget"
        let service = ScriptAIService(usesPrivateCloudCompute: false, capabilities: FakeAIModelCapabilities(device: .available))
        let script = try service.finishedDraft(
            draft, request: request(brief: IdeaBrief(subject: "  \(long) ", angle: "", openingLine: "")), model: .onDevice, timings: timings
        )
        #expect(script.title == long)
    }

    @Test func aTypedRequestKeepsTheModelsShortTitle() throws {
        let service = ScriptAIService(usesPrivateCloudCompute: false, capabilities: FakeAIModelCapabilities(device: .available))
        #expect(try service.finishedDraft(draft, request: request(), model: .onDevice, timings: timings).title == "Water bottles")
        #expect(request(brief: IdeaBrief(subject: " ", angle: "", openingLine: "")).ideaTitle == nil)
    }
}
