//
//  UltraFitReply.swift
//  Cue Studio
//

import Foundation

/// "Fit to time"'s answer (`UltraInstructions.fitter`): the fitted speech alone. Read strictly, as the other answers are: anything else is a
/// failed fit and the script on the page stays as it was.
nonisolated struct UltraFitReply: Hashable, Sendable {
    let script: String

    private struct Wire: Decodable {
        let script: String
    }

    /// Nil when `json` isn't exactly the one key with a script in it.
    init?(json: String) {
        guard let data = json.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any], Set(object.keys) == ["script"],
              let wire = try? JSONDecoder().decode(Wire.self, from: data) else { return nil }
        let script = wire.script.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !script.isEmpty else { return nil }
        self.script = script
    }
}
