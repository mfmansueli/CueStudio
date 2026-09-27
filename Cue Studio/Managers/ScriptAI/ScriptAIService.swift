//
//  ScriptAIService.swift
//  Cue Studio
//

import Foundation
import FoundationModels

/// Writes scripts with Apple's on-device model. Nothing leaves the device.
/// Without Apple Intelligence, generation falls back to the structured draft built from the brief.
@MainActor
@Observable
final class ScriptAIService: ScriptWriting {
    var isLanguageModelAvailable: Bool {
        SystemLanguageModel.default.isAvailable
    }

    var unavailableReason: String? {
        switch SystemLanguageModel.default.availability {
        case .available:
            nil
        case .unavailable(.deviceNotEligible):
            String(localized: "This device doesn't support Apple Intelligence.")
        case .unavailable(.appleIntelligenceNotEnabled):
            String(localized: "Turn on Apple Intelligence in Settings to use AI tools.")
        case .unavailable(.modelNotReady):
            String(localized: "Apple Intelligence is still getting ready. Try again in a few minutes.")
        case .unavailable:
            String(localized: "Apple Intelligence isn't available right now.")
        }
    }

    func generate(_ request: ScriptRequest) async throws -> GeneratedScript {
        let title = request.type.draftTitle(from: request.brief)
        guard isLanguageModelAvailable else {
            return GeneratedScript(title: title, text: structuredDraft(for: request), usedLanguageModel: false)
        }
        let session = LanguageModelSession(instructions: ScriptPromptBuilder.instructions(for: request))
        let response = try await session.respond(to: ScriptPromptBuilder.prompt(for: request))
        let text = ScriptPromptBuilder.clean(response.content)
        guard !text.isEmpty else { throw ScriptAIError.emptyResponse }
        return GeneratedScript(title: title, text: text, usedLanguageModel: true)
    }

    func rewrite(_ text: String, with tool: ScriptTool, context: RewriteContext) async throws -> String {
        guard isLanguageModelAvailable else {
            throw ScriptAIError.modelUnavailable(unavailableReason ?? "")
        }
        let session = LanguageModelSession(instructions: ScriptPromptBuilder.rewriteInstructions())
        let response = try await session.respond(to: ScriptPromptBuilder.rewritePrompt(for: text, tool: tool, context: context))
        let rewritten = ScriptPromptBuilder.clean(response.content)
        guard !rewritten.isEmpty else { throw ScriptAIError.emptyResponse }
        return rewritten
    }

    /// The brief turned into the format's structure, with the creator's first catchphrase up front.
    private func structuredDraft(for request: ScriptRequest) -> String {
        let draft = request.type.draft(from: request.brief)
        guard let phrase = request.phrases.first, !request.type.structure.isSerious else { return draft }
        return "\(phrase) — \(ScriptType.lowercasedFirst(draft))"
    }
}
