//
//  ScriptVerbatimProtection.swift
//  Cue Studio
//

import Foundation

/// Protects only wording already present in the model's answer from cleanup. It never inserts a
/// missing phrase or bypasses a model refusal. The final requirement check still decides delivery.
nonisolated struct ScriptVerbatimProtection {
    let text: String
    private let replacements: [(token: String, original: String)]

    init(_ text: String, phrases: [String]) {
        var protected = text.precomposedStringWithCanonicalMapping
        var replacements: [(token: String, original: String)] = []
        for phrase in phrases.sorted(by: { $0.count > $1.count }) where !phrase.isEmpty {
            let canonical = phrase.precomposedStringWithCanonicalMapping
            guard protected.contains(canonical) else { continue }
            let token = "CUEVERBATIM" + UUID().uuidString.replacingOccurrences(of: "-", with: "")
            protected = protected.replacingOccurrences(of: canonical, with: token)
            replacements.append((token, phrase))
        }
        self.text = protected
        self.replacements = replacements
    }

    func restoring(in text: String) -> String {
        replacements.reduce(text) { $0.replacingOccurrences(of: $1.token, with: $1.original) }
    }
}
