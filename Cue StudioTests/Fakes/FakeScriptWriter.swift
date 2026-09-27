//
//  FakeScriptWriter.swift
//  Cue StudioTests
//

import Foundation
@testable import Cue_Studio

@MainActor
final class FakeScriptWriter: ScriptWriting {
    var isLanguageModelAvailable = true
    var unavailableReason: String? = "Apple Intelligence is off."
    var generatedText = "Hey there. [pause]\n\nThis is the body.\n\nFollow for more."
    var rewrittenText = "Rewritten with energy!"
    var error: Error?
    private(set) var lastRequest: ScriptRequest?
    private(set) var lastRewrite: (tool: ScriptTool, context: RewriteContext)?

    func generate(_ request: ScriptRequest) async throws -> GeneratedScript {
        if let error { throw error }
        lastRequest = request
        if isLanguageModelAvailable {
            return GeneratedScript(title: request.type.draftTitle(from: request.brief), text: generatedText, usedLanguageModel: true)
        }
        return GeneratedScript(title: request.type.draftTitle(from: request.brief), text: request.type.draft(from: request.brief), usedLanguageModel: false)
    }

    func rewrite(_ text: String, with tool: ScriptTool, context: RewriteContext) async throws -> String {
        if let error { throw error }
        guard isLanguageModelAvailable else { throw ScriptAIError.modelUnavailable(unavailableReason ?? "") }
        lastRewrite = (tool, context)
        return rewrittenText
    }
}
