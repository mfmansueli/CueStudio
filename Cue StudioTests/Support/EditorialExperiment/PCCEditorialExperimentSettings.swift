//
//  PCCEditorialExperimentSettings.swift
//  Cue StudioTests
//

import FoundationModels

/// Only explicit, recorded configurations enter the native comparison; typos must not silently run a different experiment.
nonisolated struct PCCEditorialExperimentSettings: Sendable {
    let voice: QualityProfile.Condition
    let reasoning: String
    let creativeSampling: Bool
    let modes: [String]

    init?(environment: [String: String]) {
        guard let voice = QualityProfile.Condition(rawValue: environment["CUE_QUALITY_ABLATION_VOICE"] ?? "full") else { return nil }
        let reasoning = environment["CUE_QUALITY_REASONING"] ?? "default"
        guard ["default", "light", "moderate", "deep"].contains(reasoning) else { return nil }
        let sampling = environment["CUE_QUALITY_ABLATION_SAMPLING"] ?? "default"
        guard ["default", "creative"].contains(sampling) else { return nil }
        let modes = environment["CUE_QUALITY_ABLATION_MODES"]?.split(separator: ",").map(String.init)
            ?? ["baseline", "stack-guided", "lean-guided", "lean-raw"]
        guard !modes.isEmpty, Set(modes).count == modes.count,
              modes.allSatisfy({ Self.allowedModes.contains($0) }),
              sampling != "creative" || !modes.contains("baseline"),
              !modes.contains("bare-raw") || voice == .none else { return nil }
        self.voice = voice
        self.reasoning = reasoning
        creativeSampling = sampling == "creative"
        self.modes = modes
    }

    static let allowedModes = [
        "baseline", "stack-guided", "lean-guided", "lean-raw", "editorial-raw",
        "editorial-demo-raw", "staged-raw", "angle-search-raw", "bare-raw", "editorial-pt-raw",
    ]

    var reasoningLevel: ContextOptions.ReasoningLevel? {
        switch reasoning {
        case "light": .light
        case "moderate": .moderate
        case "deep": .deep
        default: nil
        }
    }

    var description: String {
        "Evaluation settings (not model input): voice=\(voice.rawValue); reasoning=\(reasoning); sampling="
            + (creativeSampling ? "random-top-p0.95-temperature0.8-seed17" : "default")
    }

    func options(responseCap: Int) -> GenerationOptions {
        GenerationOptions(
            samplingMode: creativeSampling ? .random(probabilityThreshold: 0.95, seed: 17) : nil,
            temperature: creativeSampling ? 0.8 : nil, maximumResponseTokens: responseCap
        )
    }
}
