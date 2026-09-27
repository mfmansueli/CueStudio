//
//  StubScriptWriter.swift
//  Cue Studio
//

#if DEBUG
import Foundation

/// A predictable writer for UI tests (`-uiTestStubAI`, or `-uiTestNoAI` for a device without Apple
/// Intelligence): no model, no network, instant answers.
@MainActor
final class StubScriptWriter: ScriptWriting {
    let availability: AIAvailability

    init(available: Bool) {
        availability = available
            ? AIAvailability(onDevice: true, privateCloud: true, reason: nil)
            : .unavailable
    }

    func generate(_ request: ScriptRequest) async throws -> GeneratedScript {
        switch request.source {
        case .prompt(let text):
            guard availability.isAvailable else { throw ScriptAIError.modelUnavailable(availability.reason ?? "") }
            return GeneratedScript(
                title: String(text.prefix(40)),
                text: "[confident] Let's talk about this. [pause]\n\nHere's the short version.\n\nSave this for later. [look at camera]",
                usedLanguageModel: true,
                needsFactCheck: request.isFactualTopic,
                model: .privateCloud
            )
        case .format(let type, let brief):
            return GeneratedScript(title: type.draftTitle(from: brief), text: type.draft(from: brief), usedLanguageModel: availability.isAvailable, model: .onDevice)
        }
    }

    func rewrite(_ text: String, with tool: ScriptTool, context: RewriteContext) async throws -> String {
        guard availability.isAvailable else { throw ScriptAIError.modelUnavailable(availability.reason ?? "") }
        return text + "\n\n[smile] Rewritten."
    }

    func hooks(for text: String, context: RewriteContext) async throws -> [String] {
        guard availability.isAvailable else { throw ScriptAIError.modelUnavailable(availability.reason ?? "") }
        return ["Stub hook one.", "Stub hook two.", "Stub hook three."]
    }

    func themeIdeas(for niches: [Niche]) async throws -> [ThemeIdea] {
        guard availability.isAvailable else { throw ScriptAIError.modelUnavailable(availability.reason ?? "") }
        return [ThemeIdea(title: "A stub idea for testing", kind: "List", length: .minute1, niche: niches.first ?? .lifestyle)]
    }
}
#endif
