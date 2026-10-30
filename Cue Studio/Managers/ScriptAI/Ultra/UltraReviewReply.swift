//
//  UltraReviewReply.swift
//  Cue Studio
//

import Foundation

/// The editor's answer (`UltraInstructions.editor`): the title, the final speech and what was changed. Read strictly: anything else (a missing
/// script, extra keys, a list of changes that isn't text) is a failed polish, never a finished script, and the draft is not passed off as one.
nonisolated struct UltraReviewReply: Hashable, Sendable {
    let title: String
    let script: String
    let changes: [String]

    /// The most changes a real list holds: more is the model listing its thinking.
    static let changeLimit = 12

    private struct Wire: Decodable {
        let title: String
        let script: String
        let changes: [String]
    }

    private static let keys: Set = ["title", "script", "changes"]

    /// Nil when `json` isn't exactly the three keys with a script in them.
    init?(json: String) {
        guard let data = json.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any], Set(object.keys) == Self.keys,
              let wire = try? JSONDecoder().decode(Wire.self, from: data) else { return nil }
        let script = wire.script.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !script.isEmpty, wire.changes.count <= Self.changeLimit else { return nil }
        title = wire.title.trimmingCharacters(in: .whitespacesAndNewlines.union(CharacterSet(charactersIn: "\"“”")))
        self.script = script
        changes = wire.changes.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
    }
}
