//
//  ScriptAIService.swift
//  Cue Studio
//

import Foundation
import FoundationModels
import os

/// Writes scripts with Apple Intelligence and nothing else: the on-device model for rewrites, hooks
/// and ideas (fast, offline), Private Cloud Compute for free prompts (more knowledge), each covering
/// for the other (`AIModelRoute.fallback(after:)`). Scripts come back structured (`ScriptDraft`),
/// never as free text to parse. Without any model, formats still get their structured draft built
/// from the brief.
@MainActor
@Observable
final class ScriptAIService: ScriptWriting {
    /// Private Cloud Compute needs the managed `com.apple.developer.private-cloud-compute`
    /// entitlement, which Apple grants to the team on request: until then Xcode can't put it in a
    /// provisioning profile ("Entitlement … not found and could not be included in profile"), and
    /// without it FoundationModels stops the app on the first request (a fatal error, not a thrown
    /// one) while `isAvailable` still says yes. So it stays off until the entitlement is in
    /// `Cue Studio.entitlements` (a test keeps the two in sync). Meanwhile everything is written on
    /// the device.
    static let hasPrivateCloudComputeEntitlement = false

    /// Nil while Private Cloud Compute is off.
    private let privateCloud: PrivateCloudComputeLanguageModel?
    private let logger = Logger(subsystem: "studio.cue", category: "ScriptAI")

    init(usesPrivateCloudCompute: Bool = ScriptAIService.hasPrivateCloudComputeEntitlement) {
        privateCloud = usesPrivateCloudCompute ? PrivateCloudComputeLanguageModel() : nil
    }

    /// Private Cloud Compute counts as available only while this person's quota has room, so a
    /// used-up quota sends prompts to the device without a request that is bound to fail.
    var availability: AIAvailability {
        let onDevice = SystemLanguageModel.default.isAvailable
        let cloud = privateCloud.map { $0.isAvailable && !$0.quotaUsage.isLimitReached } ?? false
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
        let begin = ContinuousClock.now
        let task: AIModelRoute.Task = request.isFreePrompt ? .freePrompt : .format
        guard let route = route(for: task) else {
            guard case .format(let type, let brief) = request.source else {
                throw ScriptAIError.modelUnavailable(unavailableReason)
            }
            return GeneratedScript(
                title: type.draftTitle(from: brief, language: request.language),
                text: structuredDraft(type: type, brief: brief, voice: request.voice, language: request.language),
                usedLanguageModel: false
            )
        }
        return try await withFallback(from: route) { model in
            try await self.draft(request, on: model, since: begin)
        }
    }

    /// Streams the draft so the time to the first words can be told apart from the time to the last.
    /// `begin` is when `generate` was called: choosing the model and building the request count as
    /// preparation, up to the moment the request goes out.
    private func draft(_ request: ScriptRequest, on model: AIModelRoute, since begin: ContinuousClock.Instant) async throws -> GeneratedScript {
        let clock = ContinuousClock()
        let session = session(on: model, instructions: ScriptPromptBuilder.instructions(for: request))
        let prompt = ScriptPromptBuilder.prompt(for: request)
        let started = clock.now
        var firstResponse: Duration?
        var latest: GeneratedContent?
        for try await snapshot in session.streamResponse(to: prompt, generating: ScriptDraft.self) {
            if firstResponse == nil { firstResponse = started.duration(to: clock.now) }
            latest = snapshot.rawContent
        }
        try Task.checkCancellation()
        guard let latest else { throw ScriptAIError.emptyResponse }
        let draft = try ScriptDraft(latest)
        let timings = GenerationTimings(
            prepare: begin.duration(to: started), firstResponse: firstResponse, generation: started.duration(to: clock.now)
        )
        let text = ScriptPromptBuilder.clean(draft.scriptText)
        guard !text.isEmpty else { throw ScriptAIError.emptyResponse }
        let title: String = switch request.source {
        case .format(let type, let brief): type.draftTitle(from: brief, language: request.language)
        case .prompt: ScriptPromptBuilder.cleanTitle(draft.title)
        }
        return GeneratedScript(
            title: title,
            text: text,
            usedLanguageModel: true,
            needsFactCheck: request.isFreePrompt && (request.isFactualTopic || draft.statesFacts),
            model: model,
            timings: timings
        )
    }

    /// The brief turned into the format's structure, with the creator's first catchphrase up front.
    private func structuredDraft(type: ScriptType, brief: [String: String], voice: CreatorVoice?, language: CueLanguage?) -> String {
        let draft = type.draft(from: brief, language: language)
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

    func themeIdeas(for niches: [Niche], language: CueLanguage?) async throws -> [ThemeIdea] {
        guard let route = route(for: .themes) else {
            throw ScriptAIError.modelUnavailable(unavailableReason)
        }
        let known = niches.isEmpty ? [Niche.lifestyle] : niches
        return try await withFallback(from: route) { model in
            let session = self.session(on: model, instructions: "You suggest video ideas for creators who film themselves talking to camera.")
            let prompt = ScriptPromptBuilder.themesPrompt(for: known, language: language)
            let suggestions = try await session.respond(to: prompt, generating: ThemeSuggestions.self).content
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
        if model == .privateCloud, let privateCloud {
            return LanguageModelSession(model: privateCloud, instructions: instructions)
        }
        return LanguageModelSession(model: SystemLanguageModel.default, instructions: instructions)
    }

    /// Runs `work` on `model` and, when the other model can do what this one couldn't, tries once
    /// more there: the device when Private Cloud Compute is out of reach (no network, quota
    /// reached, service down), Private Cloud Compute when a script is too long or in a language
    /// the device model doesn't write. What still fails is explained in Cue's words.
    private func withFallback<Result>(
        from model: AIModelRoute,
        _ work: (AIModelRoute) async throws -> Result
    ) async throws -> Result {
        do {
            return try await work(model)
        } catch {
            let failure = AIFailure(error)
            guard let fallback = model.fallback(after: failure), isAvailable(fallback) else {
                throw Self.explained(error, failure: failure)
            }
            logger.notice("""
                \(String(describing: model)) failed (\(String(describing: failure))), trying \(String(describing: fallback)): \
                \(error.localizedDescription)
                """)
            do {
                return try await work(fallback)
            } catch {
                throw Self.explained(error, failure: AIFailure(error))
            }
        }
    }

    private func isAvailable(_ model: AIModelRoute) -> Bool {
        let availability = availability
        return switch model {
        case .onDevice: availability.onDevice
        case .privateCloud: availability.privateCloud
        }
    }

    /// The framework's own message for a long script or a missing language is written for
    /// developers; the creator gets Cue's.
    private static func explained(_ error: any Error, failure: AIFailure) -> any Error {
        switch failure {
        case .tooLong: ScriptAIError.tooLong
        case .unsupportedLanguage: ScriptAIError.unsupportedLanguage
        case .cloudUnreachable, .other: error
        }
    }
}
