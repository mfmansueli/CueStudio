//
//  ScriptWriting.swift
//  Cue Studio
//

import Foundation

/// Drafts and rewrites scripts. Screens depend on this protocol so tests can use a fake writer.
protocol ScriptWriting: AnyObject {
    /// Whether the on-device language model can be used right now.
    var isLanguageModelAvailable: Bool { get }
    /// Why the model is unavailable, in words for the creator. Nil when available.
    var unavailableReason: String? { get }

    /// Drafts a script. Falls back to the structured draft when the model is unavailable.
    func generate(_ request: ScriptRequest) async throws -> GeneratedScript

    /// Rewrites `text` with a tool. Throws `ScriptAIError.modelUnavailable` without the model.
    func rewrite(_ text: String, with tool: ScriptTool, context: RewriteContext) async throws -> String
}
