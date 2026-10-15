//
//  FakePromptMeasure.swift
//  Cue StudioTests
//

import Foundation
@testable import Cue_Studio

/// A model's count of a request, as a rule: the estimate (`PromptCost`) times a factor, as a script that takes more tokens per character would.
nonisolated struct FakePromptMeasure: PromptMeasuring {
    var window: Int? = 4096
    /// Tokens per estimated token: 1 is English-like, 3 is the cost of a script the estimate underrates.
    var factor = 1.0
    var structure = 160

    func tokens(instructions: String, prompt: String, structure kind: ResponseStructure) async -> Int? {
        Int(Double(PromptCost.tokens(of: instructions) + PromptCost.tokens(of: prompt)) * factor) + (kind == .text ? 0 : structure)
    }
}
