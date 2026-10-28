//
//  AIGenerationBudget.swift
//  Cue Studio
//

import Foundation

/// One allowance shared by a cloud draft and all of its voice/language corrections.
@MainActor
final class AIGenerationBudget {
    private let maximum: Int
    private var used = 0

    init(maximum: Int) { self.maximum = maximum }

    var remaining: Int { maximum - used }

    func consume() throws {
        guard used < maximum else { throw ScriptAIError.emptyResponse }
        used += 1
    }
}
