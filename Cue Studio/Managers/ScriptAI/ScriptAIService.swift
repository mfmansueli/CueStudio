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
        let language = languages.first?.identifier
        let plan: AIPlan
        switch await planner.plan(task, languages: languages) {
        case .success(let planned):
            plan = planned
        case .failure(let failure):
            // A format has its own structured draft, in the language, that needs no model at all.
            guard case .format(let type, let brief) = request.source else {
                AIFailureReport.note(failure, operation: "script", route: nil, language: language, seconds: 0, isFinal: true)
                throw failure.error()
            }
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
        return try await withFallback(plan, retriesRunaway: inputSize < Self.smallInput, operation: "script", language: language) { model in
            let attempt = ContinuousClock.now
            do {
                return try await self.draft(request, on: model, since: begin)
            } catch ScriptAIError.wrongLanguage {
                // Measured on an iPhone: a Japanese idea with an English catchphrase came back in English. One more try,
                // told plainly; if it still isn't in the language, the creator is told and nothing is saved.
                AIFailureReport.note(
                    ScriptAIError.wrongLanguage, operation: "script", route: model, language: language,
                    seconds: attempt.duration(to: .now).inSeconds, isFinal: false
                )
                return try await self.draft(request, on: model, since: begin, insistsOnLanguage: true)
            } catch ScriptAIError.emptyResponse {
                // Measured on an iPhone: now and then a request comes back with nothing in it, and the same one works at once.
                AIFailureReport.note(
                    ScriptAIError.emptyResponse, operation: "script", route: model, language: language,
                    seconds: attempt.duration(to: .now).inSeconds, isFinal: false
                )
                return try await self.draft(request, on: model, since: begin)
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
        var partial: ScriptDraft.PartiallyGenerated?
        // A bound on the answer: measured on an iPhone, a script the model kept on writing past its end ran 60 s and more
        // before "context size exceeded". The bound is generous (three tokens a word and room for the structure).
        let options = GenerationOptions(maximumResponseTokens: Self.responseTokens(for: request))
        var rescued: ScriptDraft?
        do {
            for try await snapshot in session.streamResponse(to: prompt, generating: ScriptDraft.self, options: options) {
                if firstResponse == nil { firstResponse = started.duration(to: clock.now) }
                latest = snapshot.rawContent
                partial = snapshot.content
            }
        } catch {
            // A model that ran on past the end of a script it had already written: what arrived is the script.
                guard AIFailure(error) == .tooLong, let draft = Self.rescued(partial, request: request) else { throw error }
            logger.notice("The model ran on past the end of the script; using what had arrived")
            rescued = draft
        }
        try Task.checkCancellation()
        let draft: ScriptDraft
        if let rescued {
            draft = rescued
        } else {
            guard let latest else { throw ScriptAIError.emptyResponse }
            if let complete = try? ScriptDraft(latest) {
                draft = complete
            } else if let cut = Self.rescued(partial, request: request) {
                // The bound ended it before the last field: the blocks that arrived are the script.
                draft = cut
            } else {
                throw ScriptAIError.emptyResponse
            }
        }
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
        let operation = "rewrite.\(tool)"
        let language = expected?.minimalIdentifier
        let voice = tool == .inMyVoice ? context.voice : nil
        func attempt(on model: AIModelRoute) async throws -> String {
            let session = self.session(on: model, instructions: ScriptPromptBuilder.rewriteInstructions(voice: voice, language: expected))
            let response = try await session.respond(to: ScriptPromptBuilder.rewritePrompt(for: text, tool: tool, context: context))
            let rewritten = ScriptPromptBuilder.clean(response.content)
            guard !rewritten.isEmpty else { throw ScriptAIError.emptyResponse }
            try Self.requireLanguage(expected, in: rewritten)
            return rewritten
        }
        return try await withFallback(plan, operation: operation, language: language) { model in
            do {
                return try await attempt(on: model)
            } catch ScriptAIError.wrongLanguage {
                AIFailureReport.note(ScriptAIError.wrongLanguage, operation: operation, route: model, language: language, seconds: 0, isFinal: false)
                // Measured on an iPhone: "In my voice" on a Japanese script came back in English. One more try; then the
                // creator is told and the script stays as it was.
                return try await attempt(on: model)
            }
        }
    }

    func hooks(for text: String, context: RewriteContext) async throws -> [String] {
        let plan = try await plan(for: .hooks, languages: context.sourceLanguage.map { [$0] } ?? [])
        return try await withFallback(plan, operation: "hooks", language: context.sourceLanguage?.minimalIdentifier) { model in
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
        return try await withFallback(plan, operation: "themes", language: language?.locale.identifier) { model in
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
        case .success(let plan):
            return plan
        case .failure(let failure):
            AIFailureReport.note(failure, operation: "\(task)", route: nil, language: languages.first?.minimalIdentifier, seconds: 0, isFinal: true)
            throw failure.error(translation: translation)
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
    /// still fails is explained in Cue's words. Every attempt that fails is written down (`AIFailureReport`): what was asked
    /// (`operation`, in `language`), the framework's reason and the iPhone's conditions.
    func withFallback<Result>(
        _ plan: AIPlan,
        retriesRunaway: Bool = false,
        operation: String = "script",
        language: String? = nil,
        _ work: (AIModelRoute) async throws -> Result
    ) async throws -> Result {
        var started = ContinuousClock.now
        func note(_ error: any Error, on route: AIModelRoute, isFinal: Bool) {
            AIFailureReport.note(
                error, operation: operation, route: route, language: language, seconds: started.duration(to: .now).inSeconds, isFinal: isFinal
            )
            started = .now
        }
        do {
            return try await work(plan.route)
        } catch {
            var error = error
            var failure = AIFailure(error)
            if failure == .tooLong, retriesRunaway {
                note(error, on: plan.route, isFinal: false)
                do {
                    return try await work(plan.route)
                } catch let second {
                    error = second
                    failure = AIFailure(second)
                }
            }
            guard let fallback = plan.fallback(from: plan.route, after: failure) else {
                note(error, on: plan.route, isFinal: true)
                throw Self.explained(error, failure: failure)
            }
            note(error, on: plan.route, isFinal: false)
            do {
                return try await work(fallback)
            } catch {
                note(error, on: fallback, isFinal: true)
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
        case .rateLimited: ScriptAIError.rateLimited
        case .cancelled: CancellationError()
        case .cloudUnreachable, .other: error
        }
    }

    /// Tokens the answer may take: three a word of the longest script asked for, and room for the structure around it.
    static func responseTokens(for request: ScriptRequest) -> Int {
        let words = ReadTime.words(for: request.targetRange.upperBound)
        return min(1_800, max(600, words * 3 + 350))
    }

    /// The script out of an answer that stopped before it was complete: needs at least two blocks with text and half
    /// the words asked for, so a few lines before a failure are never passed off as a script.
    static func rescued(_ partial: ScriptDraft.PartiallyGenerated?, request: ScriptRequest) -> ScriptDraft? {
        guard let partial else { return nil }
        let blocks = (partial.blocks ?? []).compactMap { block -> ScriptDraft.Block? in
            guard let text = block.text?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty else { return nil }
            return ScriptDraft.Block(label: block.label ?? "", text: text)
        }
        let words = blocks.reduce(0) { $0 + ReadTime.wordCount(in: CueParser.stripCues($1.text)) }
        guard blocks.count >= 2, words >= max(15, ReadTime.words(for: request.targetRange.lowerBound) / 2) else { return nil }
        return ScriptDraft(title: partial.title ?? "", blocks: blocks, statesFacts: partial.statesFacts ?? false)
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
