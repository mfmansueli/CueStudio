//
//  ScriptAIService.swift
//  Cue Studio
//

import Foundation
import FoundationModels
import os

/// Writes scripts with Apple Intelligence and nothing else: the on-device model for rewrites, hooks
/// and ideas (fast, offline), Private Cloud Compute for free prompts (more knowledge), each falling
/// back to the other. Scripts come back structured (`ScriptDraft`), never as free text to parse.
/// Without any model, formats still get their structured draft built from the brief.
@MainActor
@Observable
final class ScriptAIService: ScriptWriting {
    private let privateCloud = PrivateCloudComputeLanguageModel()
    private let logger = Logger(subsystem: "studio.cue", category: "ScriptAI")

    var availability: AIAvailability {
        let onDevice = SystemLanguageModel.default.isAvailable
        let cloud = privateCloud.isAvailable
        return AIAvailability(
            onDevice: onDevice,
            privateCloud: cloud,
            reason: onDevice || cloud ? nil : unavailableReason
        )
    }

    private var unavailableReason: String {
        switch SystemLanguageModel.default.availability {
        case .available:
            String(localized: "Apple Intelligence isn't available right now.")
        case .unavailable(.deviceNotEligible):
            String(localized: "Requires Apple Intelligence. This device doesn't support it.")
        case .unavailable(.appleIntelligenceNotEnabled):
            String(localized: "Requires Apple Intelligence. Turn it on in Settings to use AI tools.")
        case .unavailable(.modelNotReady):
            String(localized: "Apple Intelligence is still getting ready. Try again in a few minutes.")
        case .unavailable:
            String(localized: "Requires Apple Intelligence.")
        }
    }

    // MARK: - Scripts

    func generate(_ request: ScriptRequest) async throws -> GeneratedScript {
        let task: AIModelRoute.Task = request.isFreePrompt ? .freePrompt : .format
        guard let route = route(for: task) else {
            guard case .format(let type, let brief) = request.source else {
                throw ScriptAIError.modelUnavailable(unavailableReason)
            }
            return GeneratedScript(title: type.draftTitle(from: brief), text: structuredDraft(type: type, brief: brief, voice: request.voice), usedLanguageModel: false)
        }
        return try await withFallback(from: route) { model in
            try await self.draft(request, on: model)
        }
    }

    private func draft(_ request: ScriptRequest, on model: AIModelRoute) async throws -> GeneratedScript {
        let session = session(on: model, instructions: ScriptPromptBuilder.instructions(for: request))
        let draft = try await session.respond(to: ScriptPromptBuilder.prompt(for: request), generating: ScriptDraft.self).content
        let text = ScriptPromptBuilder.clean(draft.scriptText)
        guard !text.isEmpty else { throw ScriptAIError.emptyResponse }
        let title: String = switch request.source {
        case .format(let type, let brief): type.draftTitle(from: brief)
        case .prompt: ScriptPromptBuilder.cleanTitle(draft.title)
        }
        return GeneratedScript(
            title: title,
            text: text,
            usedLanguageModel: true,
            needsFactCheck: request.isFreePrompt && (request.isFactualTopic || draft.statesFacts),
            model: model
        )
    }

    /// The brief turned into the format's structure, with the creator's first catchphrase up front.
    private func structuredDraft(type: ScriptType, brief: [String: String], voice: CreatorVoice?) -> String {
        let draft = type.draft(from: brief)
        guard let phrase = voice?.phrases.first, !type.structure.isSerious else { return draft }
        return "\(phrase) — \(ScriptType.lowercasedFirst(draft))"
    }

    // MARK: - Editing

    func rewrite(_ text: String, with tool: ScriptTool, context: RewriteContext) async throws -> String {
        guard let route = route(for: .rewrite) else {
            throw ScriptAIError.modelUnavailable(unavailableReason)
        }
        let voice = tool == .inMyVoice ? context.voice : nil
        return try await withFallback(from: route) { model in
            let session = self.session(on: model, instructions: ScriptPromptBuilder.rewriteInstructions(voice: voice))
            let response = try await session.respond(to: ScriptPromptBuilder.rewritePrompt(for: text, tool: tool, context: context))
            let rewritten = ScriptPromptBuilder.clean(response.content)
            guard !rewritten.isEmpty else { throw ScriptAIError.emptyResponse }
            return rewritten
        }
    }

    func hooks(for text: String, context: RewriteContext) async throws -> [String] {
        guard let route = route(for: .hooks) else {
            throw ScriptAIError.modelUnavailable(unavailableReason)
        }
        return try await withFallback(from: route) { model in
            let session = self.session(on: model, instructions: ScriptPromptBuilder.rewriteInstructions(voice: context.voice))
            let ideas = try await session.respond(to: ScriptPromptBuilder.hooksPrompt(for: text, context: context), generating: HookIdeas.self).content
            let hooks = ideas.hooks.map(ScriptPromptBuilder.cleanTitle).filter { !$0.isEmpty }
            guard !hooks.isEmpty else { throw ScriptAIError.emptyResponse }
            return Array(hooks.prefix(3))
        }
    }

    func themeIdeas(for niches: [Niche]) async throws -> [ThemeIdea] {
        guard let route = route(for: .themes) else {
            throw ScriptAIError.modelUnavailable(unavailableReason)
        }
        let known = niches.isEmpty ? [Niche.lifestyle] : niches
        return try await withFallback(from: route) { model in
            let session = self.session(on: model, instructions: "You suggest video ideas for creators who film themselves talking to camera.")
            let suggestions = try await session.respond(to: ScriptPromptBuilder.themesPrompt(for: known), generating: ThemeSuggestions.self).content
            let ideas = suggestions.ideas.compactMap { idea -> ThemeIdea? in
                let title = ScriptPromptBuilder.cleanTitle(idea.title)
                guard !title.isEmpty else { return nil }
                let niche = known.first { $0.label.caseInsensitiveCompare(idea.niche) == .orderedSame } ?? known[0]
                return ThemeIdea(title: title, kind: idea.kind.capitalized, length: idea.minutes >= 2 ? .minutes2 : .minute1, niche: niche)
            }
            guard !ideas.isEmpty else { throw ScriptAIError.emptyResponse }
            return ideas
        }
    }

    // MARK: - Models

    private func route(for task: AIModelRoute.Task) -> AIModelRoute? {
        let availability = availability
        return AIModelRoute.choose(for: task, onDeviceAvailable: availability.onDevice, privateCloudAvailable: availability.privateCloud)
    }

    private func session(on model: AIModelRoute, instructions: String) -> LanguageModelSession {
        switch model {
        case .onDevice: LanguageModelSession(model: SystemLanguageModel.default, instructions: instructions)
        case .privateCloud: LanguageModelSession(model: privateCloud, instructions: instructions)
        }
    }

    /// Runs `work` on `model`; when Private Cloud Compute fails (no network, quota reached, service
    /// down) and the device model can run, tries again on the device.
    private func withFallback<Result>(
        from model: AIModelRoute,
        _ work: (AIModelRoute) async throws -> Result
    ) async throws -> Result {
        do {
            return try await work(model)
        } catch let error as PrivateCloudComputeLanguageModel.Error {
            guard let fallback = model.fallback, SystemLanguageModel.default.isAvailable else { throw error }
            logger.notice("Private Cloud Compute failed, writing on the device: \(error.localizedDescription)")
            return try await work(fallback)
        }
    }
}
