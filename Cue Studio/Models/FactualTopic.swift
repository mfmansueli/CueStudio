//
//  FactualTopic.swift
//  Cue Studio
//

import Foundation

/// Prompts about history, science or "how X came to be" need facts the model can get wrong: they
/// are written with Private Cloud Compute when available and the script is flagged for a fact check.
nonisolated enum FactualTopic {
    /// Words that signal a factual topic, in English and Portuguese.
    private static let signals = [
        "history", "historic", "invent", "science", "scientific", "origin", "came to be", "how did",
        "why do", "why does", "why is", "explain", "fact", "discover", "century", "who was",
        "história", "historia", "inventad", "invenção", "ciência", "origem", "como surgiu", "por que",
        "por quê", "explica", "descobert", "século", "guerra", "quem foi",
    ]

    static func isFactual(_ prompt: String) -> Bool {
        let text = prompt.lowercased()
        return signals.contains { text.contains($0) }
    }
}
