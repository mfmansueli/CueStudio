//
//  FakeUltraScriptWriter.swift
//  Cue StudioTests
//

import Foundation
@testable import Cue_Studio

/// Ultra AI as the dock and the script page see it: offered or not, allowed or not, and what a script comes back as.
@MainActor
final class FakeUltraScriptWriter: UltraScriptWriting {
    var isAvailable = true
    var isReady = true
    var scriptsLeft: Int?
    var membership: UltraAllowance.Membership?
    private(set) var aiUses = 0
    var error: (any Error)?
    var generated = GeneratedScript(
        title: "Ultra title", text: "The polished Ultra script.", usedLanguageModel: true, needsFactCheck: true, model: nil, engine: .ultra
    )
    private(set) var requests: [ScriptRequest] = []

    func noteAIUse() { aiUses += 1 }

    func generate(_ request: ScriptRequest, reporting meter: WritingProgressMeter?) async throws -> GeneratedScript {
        requests.append(request)
        if let error { throw error }
        return generated
    }
}
