//
//  ScriptIntentCase.swift
//  Cue StudioTests
//

import Foundation
@testable import Cue_Studio

/// Synthetic, frozen input cases. Expected directions guide human review; they are never fed to
/// the writer as an answer key or treated as proof of semantic quality by simulator tests.
nonisolated struct ScriptIntentCase: Decodable, Sendable {
    let id: String
    let language: CueLanguage
    let prompt: String
    let format: String
    let expectedDirection: String
    let requiredLiterals: [String]
    let reviewChecks: [String]

    var formatChoice: FormatChoice {
        if format == "talkingHead" { return .talkingHead }
        return ScriptType(rawValue: format).map(FormatChoice.type) ?? .auto
    }

    private final class BundleToken {}

    static func load() throws -> [Self] {
        guard let url = Bundle(for: BundleToken.self).url(forResource: "intent-cases", withExtension: "json") else {
            throw CocoaError(.fileNoSuchFile)
        }
        return try JSONDecoder().decode([Self].self, from: Data(contentsOf: url))
    }
}
