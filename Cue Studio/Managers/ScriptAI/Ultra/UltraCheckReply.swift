//
//  UltraCheckReply.swift
//  Cue Studio
//

import Foundation

/// The claim check's answer (`UltraInstructions.checker`): the whole draft with its claims corrected, and one line per correction. Read strictly,
/// as the polish is: anything else (a missing script, extra keys, corrections that aren't text) is a failed check, and the draft never goes on
/// to the polish as if it had been checked.
nonisolated struct UltraCheckReply: Hashable, Sendable {
    let script: String
    let corrections: [String]

    /// The most corrections a real list holds: more is the model listing its thinking.
    static let correctionLimit = 12

    private struct Wire: Decodable {
        let script: String
        let corrections: [String]
    }

    private static let keys: Set = ["script", "corrections"]

    /// Nil when `json` isn't exactly the two keys with a script in them.
    init?(json: String) {
        guard let data = json.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any], Set(object.keys) == Self.keys,
              let wire = try? JSONDecoder().decode(Wire.self, from: data) else { return nil }
        let script = wire.script.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !script.isEmpty, wire.corrections.count <= Self.correctionLimit else { return nil }
        self.script = script
        corrections = wire.corrections.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
    }
}
