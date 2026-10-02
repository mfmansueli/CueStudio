//
//  ScriptWriting.swift
//  Cue Studio
//

import Foundation

/// Drafts and rewrites scripts with Apple Intelligence. Screens depend on this protocol so tests
/// can use a fake writer.
protocol ScriptWriting: AnyObject {
    /// Which models can run right now.
    var availability: AIAvailability { get }

    /// Drafts a script. A format falls back to its structured draft when no model is available;
    /// a free prompt throws `ScriptAIError.modelUnavailable`.
    func generate(_ request: ScriptRequest) async throws -> GeneratedScript

    /// Rewrites `text` with a tool. Throws `ScriptAIError.modelUnavailable` without a model.
    func rewrite(_ text: String, with tool: ScriptTool, context: RewriteContext) async throws -> String

    /// Three new opening lines for the script.
    func hooks(for text: String, context: RewriteContext) async throws -> [String]

    /// Fresh video ideas for the creator's niches.
    /// Ideas written in `language` (the interface's, where they are shown), or the model's choice.
    func themeIdeas(for niches: [Niche], language: CueLanguage?) async throws -> [ThemeIdea]
}

extension ScriptWriting {
    var isLanguageModelAvailable: Bool { availability.isAvailable }
    var unavailableReason: String? { availability.reason }

    /// Why Apple Intelligence can't write now, in words for the creator; nil when it can.
    var writingUnavailableReason: String? {
        guard !availability.isAvailable else { return nil }
        return availability.reason ?? AIAvailability.unavailable.reason
    }
}
