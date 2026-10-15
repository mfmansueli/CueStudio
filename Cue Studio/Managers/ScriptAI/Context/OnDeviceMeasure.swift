//
//  OnDeviceMeasure.swift
//  Cue Studio
//

import Foundation
import FoundationModels

/// The on-device model's own count of a request (`SystemLanguageModel.tokenCount(for:)`) and the size of its window (`contextSize`).
nonisolated struct OnDeviceMeasure: PromptMeasuring {
    var window: Int? {
        let model = SystemLanguageModel.default
        guard case .available = model.availability else { return nil }
        return model.contextSize
    }

    func tokens(instructions: String, prompt: String, structure: ResponseStructure) async -> Int? {
        let model = SystemLanguageModel.default
        do {
            var total = try await model.tokenCount(for: Instructions(instructions)) + model.tokenCount(for: prompt)
            switch structure {
            case .script: total += try await model.tokenCount(for: ScriptDraft.generationSchema)
            case .ideas: total += try await model.tokenCount(for: IdeaBriefSuggestions.generationSchema)
            case .text: break
            }
            return total
        } catch {
            return nil
        }
    }
}
