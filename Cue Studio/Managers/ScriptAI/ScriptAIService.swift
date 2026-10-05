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
    nonisolated static let hasPrivateCloudComputeEntitlement = false

    /// Nil while Private Cloud Compute is off.
    private let privateCloud: PrivateCloudComputeLanguageModel?
    private let capabilities: AIModelCapabilities
    private let planner: AIModelPlanner
    private let logger = Logger(subsystem: "studio.cue", category: "ScriptAI")

    /// - Parameter capabilities: what the models can do and in which languages; Apple's own answers
    ///   unless a test gives a fixed list.
    init(usesPrivateCloudCompute: Bool = ScriptAIService.hasPrivateCloudComputeEntitlement, capabilities: AIModelCapabilities? = nil) {
        privateCloud = usesPrivateCloudCompute ? PrivateCloudComputeLanguageModel() : nil
        let capabilities = capabilities ?? AppleAIModelCapabilities(usesPrivateCloudCompute: usesPrivateCloudCompute)
        self.capabilities = capabilities
        planner = AIModelPlanner(capabilities: capabilities)
    }

    /// Private Cloud Compute counts as available only while this person's quota has room, so a
    /// used-up quota sends prompts to the device without a request that is bound to fail. Whether a
    /// model is available says nothing about a language: that is `writingFailure(in:)`.
    var availability: AIAvailability {
        let onDevice = capabilities.deviceStatus == .available
        let cloud = capabilities.cloudStatus == .available
        return AIAvailability(onDevice: onDevice, privateCloud: cloud, reason: onDevice || cloud ? nil : capabilities.deviceStatus.reason)
    }

    /// Why Apple Intelligence can't write in `languages` right now, told before anything is sent;
    /// nil when it can.
    func writingFailure(in languages: [Locale.Language]) -> AIPlanFailure? {
        planner.quickFailure(languages: languages.map(Self.locale(for:)))
    }

    // MARK: - Scripts

    func generate(_ request: ScriptRequest) async throws -> GeneratedScript {
        let begin = ContinuousClock.now
        let task: AIModelRoute.Task = request.isFreePrompt ? .freePrompt : .format
        let request = resolvingVariant(of: request)
        let languages = request.language.map { [request.languageVariant ?? $0.locale] } ?? []
        let plan: AIPlan
        switch await planner.plan(task, languages: languages) {
        case .success(let planned):
            plan = planned
        case .failure(let failure):
            // A format has its own structured draft, in the language, that needs no model at all.
            guard case .format(let type, let brief) = request.source else { throw failure.error() }
            return GeneratedScript(
                title: type.draftTitle(from: brief, language: request.language),
                text: structuredDraft(type: type, brief: brief, voice: request.voice, language: request.language),
                usedLanguageModel: false
            )
        }
        // A short request that still ran out of room (the model went on and on) is worth one more try on the
        // same model: the instructions and the idea are nowhere near the model's context, so "too long" can't
        // be the creator's doing, and a second run seldom does the same.
        let inputSize = ScriptPromptBuilder.instructions(for: request).count + ScriptPromptBuilder.prompt(for: request).count
        return try await withFallback(plan, retriesRunaway: inputSize < Self.smallInput) { model in
            do {
                return try await self.draft(request, on: model, since: begin)
            } catch ScriptAIError.wrongLanguage {
                // Measured on an iPhone: a Japanese idea with an English catchphrase came back in English. One more try,
                // told plainly; if it still isn't in the language, the creator is told and nothing is saved.
                return try await self.draft(request, on: model, since: begin, insistsOnLanguage: true)
            }
        }
    }

    /// The creator's regional variant is only asked of the model when the model writes it; otherwise
    /// the request is for the language as Cue offers it.
    private func resolvingVariant(of request: ScriptRequest) -> ScriptRequest {
        guard let variant = request.languageVariant, !capabilities.deviceSupports(variant) else { return request }
        var resolved = request
        resolved.languageVariant = nil
        return resolved
    }

    /// Streams the draft so the time to the first words can be told apart from the time to the last.
    /// `begin` is when `generate` was called: choosing the model and building the request count as
    /// preparation, up to the moment the request goes out.
    private func draft(
        _ request: ScriptRequest, on model: AIModelRoute, since begin: ContinuousClock.Instant, insistsOnLanguage: Bool = false
    ) async throws -> GeneratedScript {
        let clock = ContinuousClock()
        let session = session(on: model, instructions: ScriptPromptBuilder.instructions(for: request, insistsOnLanguage: insistsOnLanguage))
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
        try Self.requireLanguage(request.language?.locale.language, in: text)
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
        // The language the result must be in: the target of a translation, otherwise the script's own.
        let expected: Locale.Language?
        var needed: [Locale.Language] = []
        var pair: (source: String, target: String)?
        if tool == .translate {
            // A translation needs both languages, and never picks the target itself.
            guard let target = context.language else { throw ScriptAIError.unsupportedLanguage }
            expected = target.locale.language
            needed = [target.locale.language] + (context.sourceLanguage.map { [$0] } ?? [])
            pair = context.sourceLanguage.map { (Self.name(of: $0), target.localizedName) }
        } else {
            expected = context.sourceLanguage
            needed = context.sourceLanguage.map { [$0] } ?? []
        }
        let plan = try await plan(for: .rewrite, languages: needed, translation: pair)
        let voice = tool == .inMyVoice ? context.voice : nil
        func attempt(on model: AIModelRoute) async throws -> String {
            let session = self.session(on: model, instructions: ScriptPromptBuilder.rewriteInstructions(voice: voice, language: expected))
            let response = try await session.respond(to: ScriptPromptBuilder.rewritePrompt(for: text, tool: tool, context: context))
            let rewritten = ScriptPromptBuilder.clean(response.content)
            guard !rewritten.isEmpty else { throw ScriptAIError.emptyResponse }
            try Self.requireLanguage(expected, in: rewritten)
            return rewritten
        }
        return try await withFallback(plan) { model in
            do {
                return try await attempt(on: model)
            } catch ScriptAIError.wrongLanguage {
                // Measured on an iPhone: "In my voice" on a Japanese script came back in English. One more try; then the
                // creator is told and the script stays as it was.
                return try await attempt(on: model)
            }
        }
    }

    func hooks(for text: String, context: RewriteContext) async throws -> [String] {
        let plan = try await plan(for: .hooks, languages: context.sourceLanguage.map { [$0] } ?? [])
        return try await withFallback(plan) { model in
            let session = self.session(on: model, instructions: ScriptPromptBuilder.rewriteInstructions(voice: context.voice))
            let ideas = try await session.respond(to: ScriptPromptBuilder.hooksPrompt(for: text, context: context), generating: HookIdeas.self).content
            let hooks = ideas.hooks.map(ScriptPromptBuilder.cleanTitle).filter { !$0.isEmpty }
            guard !hooks.isEmpty else { throw ScriptAIError.emptyResponse }
            try Self.requireLanguage(context.sourceLanguage, in: hooks.joined(separator: " "))
            return Array(hooks.prefix(3))
        }
    }

    func themeIdeas(for niches: [Niche], language: CueLanguage?) async throws -> [ThemeIdea] {
        let plan = try await plan(for: .themes, languages: language.map { [$0.locale.language] } ?? [])
        let known = niches.isEmpty ? [Niche.lifestyle] : niches
        return try await withFallback(plan) { model in
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

    func pickTopic(for text: String, among topics: [String]) async -> String? {
        // The small on-device model is enough, and nothing about the script leaves the iPhone. A script in a
        // language it doesn't write stays untagged rather than tagged by a guess.
        guard !topics.isEmpty, capabilities.deviceStatus == .available else { return nil }
        if let language = LanguageDetector.dominantLanguage(in: text), !capabilities.deviceSupports(Self.locale(for: language)) { return nil }
        let session = LanguageModelSession(
            model: SystemLanguageModel.default,
            instructions: "You file a creator's video script under one of their topics. Answer with one topic exactly as given, or none."
        )
        let prompt = "Topics: \(topics.joined(separator: " | "))\n\nScript:\n\(text.prefix(1500))"
        guard let choice = try? await session.respond(to: prompt, generating: TopicChoice.self).content.topic else { return nil }
        return topics.first { $0.caseInsensitiveCompare(choice.trimmingCharacters(in: .whitespacesAndNewlines)) == .orderedSame }
    }

    // MARK: - Models

    /// The model for a task in the languages the request involves, or the reason none can take it.
    private func plan(
        for task: AIModelRoute.Task, languages: [Locale.Language], translation: (source: String, target: String)? = nil
    ) async throws -> AIPlan {
        switch await planner.plan(task, languages: languages.map(Self.locale(for:))) {
        case .success(let plan): return plan
        case .failure(let failure): throw failure.error(translation: translation)
        }
    }

    private func session(on model: AIModelRoute, instructions: String) -> LanguageModelSession {
        if model == .privateCloud, let privateCloud {
            return LanguageModelSession(model: privateCloud, instructions: instructions)
        }
        return LanguageModelSession(model: SystemLanguageModel.default, instructions: instructions)
    }

    /// Runs `work` on the plan's model and, when the other model can do what this one couldn't *and the
    /// plan knows it is available and writes the languages*, tries once more there: the device when
    /// Private Cloud Compute is out of reach, Private Cloud Compute when a script is too long. A model
    /// already known to refuse the languages is never tried. A cancellation is passed on as it is; what
    /// still fails is explained in Cue's words.
    func withFallback<Result>(
        _ plan: AIPlan,
        retriesRunaway: Bool = false,
        _ work: (AIModelRoute) async throws -> Result
    ) async throws -> Result {
        do {
            return try await work(plan.route)
        } catch {
            var error = error
            var failure = AIFailure(error)
            if failure == .tooLong, retriesRunaway {
                logger.notice("\(String(describing: plan.route)) ran out of room on a short request, trying again")
                do {
                    return try await work(plan.route)
                } catch let second {
                    error = second
                    failure = AIFailure(second)
                }
            }
            guard let fallback = plan.fallback(from: plan.route, after: failure) else {
                throw Self.explained(error, failure: failure)
            }
            logger.notice("""
                \(String(describing: plan.route)) failed (\(String(describing: failure))), trying \(String(describing: fallback)): \
                \(error.localizedDescription)
                """)
            do {
                return try await work(fallback)
            } catch {
                throw Self.explained(error, failure: AIFailure(error))
            }
        }
    }

    /// The framework's own message for a long script or a missing language is written for
    /// developers; the creator gets Cue's.
    private static func explained(_ error: any Error, failure: AIFailure) -> any Error {
        switch failure {
        case .tooLong: ScriptAIError.tooLong
        case .unsupportedLanguage: ScriptAIError.unsupportedLanguage
        case .modelPreparing: ScriptAIError.modelPreparing
        case .cancelled: CancellationError()
        case .cloudUnreachable, .other: error
        }
    }

    /// Characters of instructions and prompt below which a request can't fill the model's context by itself.
    private static let smallInput = 3_000

    // MARK: - Languages

    /// The locale the models are asked about for a language: Cue's own when it is one it offers.
    private static func locale(for language: Locale.Language) -> Locale {
        CueLanguage.matching(language: language).map(\.locale) ?? Locale(identifier: language.maximalIdentifier)
    }

    private static func name(of language: Locale.Language) -> String {
        CueLanguage.matching(language: language)?.localizedName
            ?? (InterfaceLocale.current ?? .current).localizedString(forIdentifier: language.minimalIdentifier)
            ?? language.minimalIdentifier
    }

    /// Nothing the model wrote replaces the creator's words if it isn't in the language asked for.
    private static func requireLanguage(_ expected: Locale.Language?, in text: String) throws {
        guard let expected, !OutputLanguageCheck.isPlausible(text, in: expected) else { return }
        throw ScriptAIError.wrongLanguage
    }
}
