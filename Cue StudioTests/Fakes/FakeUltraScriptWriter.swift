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
    var fitted = "The Ultra script, fitted."
    private(set) var fits: [UltraFitRequest] = []

    func noteAIUse() { aiUses += 1 }

    func fit(_ request: UltraFitRequest) async throws -> String {
        fits.append(request)
        if let error { throw error }
        return fitted
    }

    func generate(_ request: ScriptRequest, reporting meter: WritingProgressMeter?) async throws -> GeneratedScript {
        requests.append(request)
        if let error { throw error }
        return generated
    }
}
