//
//  OnboardingScript.swift
//  Cue Studio
//

import Foundation

/// The first script of the first flight: about 15 seconds, as a hook, a body and a call to action. Written
/// by the on-device model in the creator's topic, or, without a model (or in a language it can't write),
/// a short one of ours for the same topic, labelled as practice rather than as AI.
nonisolated struct OnboardingScript: Hashable, Sendable {
    var title: String
    var hook: String
    var body: String
    var cta: String
    /// Ours, not the model's: the card says "TELEPROMPTER PRACTICE" and does not claim AI.
    var isCurated: Bool

    /// The whole script, one paragraph per part.
    var text: String { [hook, body, cta].filter { !$0.isEmpty }.joined(separator: "\n\n") }

    /// The model's script, split into its three parts: with three or more paragraphs the first is the hook
    /// and the last the call to action; with fewer, the first and the last sentence.
    static func parsing(title: String, text: String) -> OnboardingScript {
        let paragraphs = text
            .components(separatedBy: "\n\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        if paragraphs.count >= 3 {
            return OnboardingScript(
                title: title, hook: paragraphs[0], body: paragraphs[1..<(paragraphs.count - 1)].joined(separator: " "),
                cta: paragraphs[paragraphs.count - 1], isCurated: false
            )
        }
        let sentences = text
            .components(separatedBy: CharacterSet(charactersIn: ".!?"))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        guard sentences.count >= 3 else {
            let rest = paragraphs.dropFirst().joined(separator: " ")
            return OnboardingScript(title: title, hook: paragraphs.first ?? text, body: "", cta: rest, isCurated: false)
        }
        return OnboardingScript(
            title: title, hook: sentences[0] + ".", body: sentences[1..<(sentences.count - 1)].joined(separator: ". ") + ".",
            cta: sentences[sentences.count - 1] + ".", isCurated: false
        )
    }

    /// Ours: the same short script for any topic, with the topic's name in the hook.
    static func curated(topic: String) -> OnboardingScript {
        OnboardingScript(
            title: topic,
            hook: String(localized: "Okay, real talk. Let’s talk about \(topic)."),
            body: String(localized: "Start small. One tiny step today beats a perfect plan tomorrow. That’s the whole trick."),
            cta: String(localized: "Try it tomorrow. Tell me how it goes."),
            isCurated: true
        )
    }
}
