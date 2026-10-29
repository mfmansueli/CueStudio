//
//  PCCEditorialAngle.swift
//  Cue StudioTests
//

import FoundationModels

@Generable
nonisolated struct PCCEditorialAngle {
    @Guide(description: "A distinct substantive claim answering the request, not a hook, metaphor or synonym of another candidate.")
    var claim: String
    @Guide(description: "Explain the mechanism or distinction that makes the claim useful. Avoid replacing an explanation with abstract positive adjectives.")
    var explanation: String
    @Guide(description: "An observable hypothetical contrast or concrete action that demonstrates the claim, without inventing the creator's history.")
    var demonstration: String

    var writingBrief: String { "Claim: \(claim)\nExplanation: \(explanation)\nDemonstration: \(demonstration)" }
}
