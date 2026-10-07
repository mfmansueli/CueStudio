//
//  VoiceBriefSnapshotTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

/// What the model is sent for each made-up creator by the prompt engine v2 (plan stage 3): the instructions and the prompt of their first idea. Kept
/// in `Fixtures/VoiceBriefs/v2`, next to `before` (what the engine sent before), so a change to what the model reads shows up as a diff in review.
/// Record again with `TEST_RUNNER_CUE_RECORD_SNAPSHOTS=1`.
@MainActor
@Suite("My Cue Voice · the brief v2")
struct VoiceBriefSnapshotTests {
    private static let folder = "VoiceBriefs/v2"

    @Test(arguments: VoicePersonas.all + VoicePersonas.languageVariants)
    func theBriefMatchesTheKeptSnapshot(persona: VoicePersona) throws {
        let request = persona.request(for: persona.ideas[0])
        #expect(request.voice != nil, "\(persona.id): the voice is part of the request")
        let brief = ScriptPromptBuilder.brief(for: persona.profile)
        let text = """
        INSTRUCTIONS
        \(ScriptPromptBuilder.instructions(for: request))

        PROMPT
        \(ScriptPromptBuilder.prompt(for: request))

        WHAT CUE SENDS · \(brief.cost) / \(VoiceBrief.budget)
        \(brief.text)
        """
        try TextSnapshot.expect(text, named: persona.id, in: Self.folder)
    }
}
