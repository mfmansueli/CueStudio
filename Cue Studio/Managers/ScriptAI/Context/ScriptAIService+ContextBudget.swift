//
//  ScriptAIService+ContextBudget.swift
//  Cue Studio
//

import Foundation
import os

extension ScriptAIService {
    /// The tokens the structure of a script's answer takes in the request (`ScriptDraft`), as the iPhone's tokenizer counted it
    /// (`ScriptQualityDeviceTests`): only for the estimate that decides whether to count at all.
    static let scriptStructureEstimate = 160

    /// `request` made to fit the window of the model that writes it: as it is when its estimate is well inside, else with less of the voice's optional
    /// parts until the model's own count says it fits (`ContextBudget`). Only the on-device model is counted; another route goes as it is.
    func fitted(_ request: ScriptRequest, on route: AIModelRoute) async -> ScriptRequest {
        guard route == .onDevice, request.voice != nil, let window = measure.window else { return request }
        let answer = Self.responseTokens(for: request)
        let estimate = PromptCost.tokens(of: ScriptPromptBuilder.instructions(for: request))
            + PromptCost.tokens(of: ScriptPromptBuilder.prompt(for: request)) + Self.scriptStructureEstimate
        guard !ContextBudget(window: window).isClearlyInside(estimate: estimate, answer: answer) else { return request }
        let candidates = [request] + ContextBudget.voiceSteps.map { budget in
            var smaller = request
            smaller.voiceBudget = budget
            return smaller
        }
        let measure = measure
        let fitted = await ContextBudget.fitting(candidates, answer: answer, window: window) { candidate in
            await measure.tokens(
                instructions: ScriptPromptBuilder.instructions(for: candidate), prompt: ScriptPromptBuilder.prompt(for: candidate), structure: .script
            )
        }
        guard let fitted else { return request }
        if let budget = fitted.candidate.voiceBudget {
            Logger(subsystem: "studio.cue", category: "ScriptAI").notice(
                "Request fitted to the window: voice budget \(budget), \(fitted.tokens ?? -1) tokens + \(answer) for the answer of \(window)"
            )
        }
        return fitted.candidate
    }
}
