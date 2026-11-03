//
//  ClaudeLabConfiguration.swift
//  Cue Studio
//

#if DEBUG
import Foundation

/// Where the Claude API key for Ultra AI's lab is on this iPhone. It is copied into the app's Documents by hand
/// (`tools/ultra/install-claude-key.sh`), never built into the app, committed or printed: a key in an app anyone installs could be read out of
/// it, so the shipped Ultra AI will call Claude through Cue's own server instead.
nonisolated enum ClaudeLabConfiguration {
    static let fileName = "UltraLab-AnthropicKey"

    static var fileURL: URL { URL.documentsDirectory.appending(path: fileName) }

    /// The key, trimmed; nil when there is none or it isn't one.
    static func apiKey() -> String? {
        guard let text = try? String(contentsOf: fileURL, encoding: .utf8) else { return nil }
        let key = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return key.hasPrefix("sk-ant-") ? key : nil
    }

    static var isPresent: Bool { apiKey() != nil }
}
#endif
