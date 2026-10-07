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

    /// Settings › Privacy & AI data › On-device AI (`PrivacyPreferencesService`).
    var isEnabled = true

    /// Nil while Private Cloud Compute is off.
    private let privateCloud: PrivateCloudComputeLanguageModel?
    private let capabilities: AIModelCapabilities
    private let planner: AIModelPlanner
    private let logger = Logger(subsystem: "studio.cue", category: "ScriptAI")
    private var foregroundRequests = 0
    private var backgroundWork: [UUID: Task<String?, Never>] = [:]

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
        beginForeground()
        defer { endForeground() }
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
            try await self.writeChecked(request, on: model, since: begin, language: language)
        }
    }

    /// One script on one model, kept to what the creator asked (`VoiceCheckedWriting`).
    private func writeChecked(
        _ request: ScriptRequest, on model: AIModelRoute, since begin: ContinuousClock.Instant, language: String?
    ) async throws -> GeneratedScript {
        let writing = VoiceCheckedWriting(
            draft: { request, violations in
                try await self.draftRepeatingLanguageOrEmpty(request, on: model, since: begin, language: language, correcting: violations)
            },
            isGuardrailRefusal: Self.isGuardrailRefusal,
            report: { error, operation in
                AIFailureReport.note(error, operation: operation, route: model, language: language, seconds: 0, isFinal: false)
            }
        )
        var script = await expandingIfShort(try await writing.write(request), for: request, on: model, language: language)
        // A script that is still a sliver of what was asked (the model wrote six words, or stopped after one block) is a failed sample, not a short one:
        // lengthening a block of a few words doesn't fix it, a fresh draft often does. One more, and the longer of the two is kept.
        let minimum = ReadTime.words(for: request.targetRange.lowerBound)
        if script.usedLanguageModel, Self.expandsShortScripts, Double(ScriptExpansion.words(in: script.text)) < Double(minimum) * Self.sliver {
            AIFailureReport.note(
                ScriptAIError.emptyResponse, operation: "script.sliver", route: model, language: language, seconds: 0, isFinal: false
            )
            if let again = try? await writing.write(request) {
                let second = await expandingIfShort(again, for: request, on: model, language: language)
                if ScriptExpansion.words(in: second.text) > ScriptExpansion.words(in: script.text) { script = second }
            }
        }
        return script
    }

    /// A script with fewer words than this share of its minimum, after it was lengthened, is written once more from the start.
    static let sliver = 0.4

    /// The script, with the one more try of what measured on an iPhone to fix itself: a Japanese idea with an English catchphrase came back
    /// in English (told plainly the second time; if it still isn't in the language, the creator is told and nothing is saved), and now and
    /// then a request comes back with nothing in it and the same one works at once.
    private func draftRepeatingLanguageOrEmpty(
        _ request: ScriptRequest, on model: AIModelRoute, since begin: ContinuousClock.Instant, language: String?,
        correcting violations: [VoiceViolation] = []
    ) async throws -> GeneratedScript {
        let attempt = ContinuousClock.now
        do {
            return try await draft(request, on: model, since: begin, correcting: violations)
        } catch ScriptAIError.wrongLanguage {
            AIFailureReport.note(
                ScriptAIError.wrongLanguage, operation: "script", route: model, language: language,
                seconds: attempt.duration(to: .now).inSeconds, isFinal: false
            )
            return try await draft(request, on: model, since: begin, insistsOnLanguage: true, correcting: violations)
        } catch ScriptAIError.emptyResponse {
            AIFailureReport.note(
                ScriptAIError.emptyResponse, operation: "script", route: model, language: language,
                seconds: attempt.duration(to: .now).inSeconds, isFinal: false
            )
            return try await draft(request, on: model, since: begin, correcting: violations)
        } catch ScriptAIError.timedOut {
            // Measured on an iPhone 15 Pro: a request that went quiet. One more, from the start; if it goes quiet too, the creator is told.
            AIFailureReport.note(
                ScriptAIError.timedOut, operation: "script", route: model, language: language,
                seconds: attempt.duration(to: .now).inSeconds, isFinal: false
            )
            return try await draft(request, on: model, since: begin, correcting: violations)
        }
    }

    /// The framework refused the request itself (not the answer): worth asking again without the creator's own words.
    private static func isGuardrailRefusal(_ error: any Error) -> Bool {
        if case LanguageModelError.guardrailViolation = error { return true }
        return false
    }

    /// The creator's regional variant is only asked of the model when the model writes it; otherwise
    /// the request is for the language as Cue offers it.
    private func resolvingVariant(of request: ScriptRequest) -> ScriptRequest {
        guard let variant = request.languageVariant, !capabilities.deviceSupports(variant) else { return request }
        var resolved = request
        resolved.languageVariant = nil
        return resolved
    }

    /// The limits a request to the model lives by (`GenerationDeadlines`); tests shorten them.
    static var deadlines = GenerationDeadlines.standard

    /// Writes the draft, and gives up on it when the model goes quiet (`ScriptAIError.timedOut`): a request that never answered kept the star on screen
    /// for ever. What had arrived by then is used when it is a script.
    private func draft(
        _ request: ScriptRequest, on model: AIModelRoute, since begin: ContinuousClock.Instant, insistsOnLanguage: Bool = false,
        correcting violations: [VoiceViolation] = []
    ) async throws -> GeneratedScript {
        let progress = GenerationProgress()
        let deadlines = Self.deadlines
        let work = Task {
            try await self.streamDraft(request, on: model, since: begin, insistsOnLanguage: insistsOnLanguage, correcting: violations, progress: progress)
        }
        let watchdog = Task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                if Task.isCancelled { return }
                if progress.checkStalled(against: deadlines) {
                    work.cancel()
                    return
                }
            }
        }
        defer { watchdog.cancel() }
        do {
            return try await withTaskCancellationHandler { try await work.value } onCancel: { work.cancel() }
        } catch {
            // Cancelled by the watchdog, not by the creator: the model went quiet.
            if progress.didStall, !Task.isCancelled { throw ScriptAIError.timedOut }
            throw error
        }
    }

    /// Streams the draft so the time to the first words can be told apart from the time to the last.
    /// `begin` is when `generate` was called: choosing the model and building the request count as
    /// preparation, up to the moment the request goes out.
    private func streamDraft(
        _ request: ScriptRequest, on model: AIModelRoute, since begin: ContinuousClock.Instant, insistsOnLanguage: Bool,
        correcting violations: [VoiceViolation], progress: GenerationProgress
    ) async throws -> GeneratedScript {
        let clock = ContinuousClock()
        let session = session(on: model, instructions: ScriptPromptBuilder.instructions(for: request, insistsOnLanguage: insistsOnLanguage))
        var prompt = ScriptPromptBuilder.prompt(for: request)
        if !violations.isEmpty { prompt += "\n" + ScriptPromptBuilder.correctionNote(for: violations) }
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
                progress.noteProgress()
                latest = snapshot.rawContent
                partial = snapshot.content
            }
        } catch {
            // A model that ran on past the end of a script it had already written, or went quiet before the end: what arrived is the script.
            guard AIFailure(error) == .tooLong || progress.didStall, let draft = Self.rescued(partial, request: request) else { throw error }
            logger.notice("The model stopped before the end of the script; using what had arrived")
            rescued = draft
        }
        // The watchdog's own cancellation is not the creator's.
        if !progress.didStall { try Task.checkCancellation() }
        let draft: ScriptDraft
        if let rescued {
            draft = rescued
        } else {
            guard let latest else {
                Self.noteEmpty("no snapshot arrived (first response \(firstResponse.map { "\($0)" } ?? "never"))")
                throw ScriptAIError.emptyResponse
            }
            if let complete = try? ScriptDraft(latest) {
                draft = complete
            } else if let cut = Self.rescued(partial, request: request) {
                // The bound ended it before the last field: the blocks that arrived are the script.
                draft = cut
            } else {
                let blocks = partial?.blocks?.count ?? 0
                let words = (partial?.blocks ?? []).reduce(0) { $0 + ReadTime.wordCount(in: $1.text ?? "") }
                Self.noteEmpty("the answer was not a script: \(blocks) blocks, \(words) words, cap \(Self.responseTokens(for: request)) tokens")
                throw ScriptAIError.emptyResponse
            }
        }
        let timings = GenerationTimings(
            prepare: begin.duration(to: started), firstResponse: firstResponse, generation: started.duration(to: clock.now)
        )
        let text = ScriptPromptBuilder.clean(draft.scriptText)
        guard !text.isEmpty else {
            Self.noteEmpty("the script was empty once cleaned: \(draft.blocks.count) blocks")
            throw ScriptAIError.emptyResponse
        }
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
        try await rewriteReported(text, with: tool, context: context).text
    }

    /// The tool at work, a part of the script at a time and each part held to the tool's promise (`RewriteRunner`), with a report of what was done.
    func rewriteReported(_ text: String, with tool: ScriptTool, context: RewriteContext) async throws -> RewriteResult {
        beginForeground()
        defer { endForeground() }
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
        let instructions = ScriptPromptBuilder.rewriteInstructions(voice: voice, language: expected)
        let ask: RewriteRunner.Ask = { [self] part, details in
            @MainActor func attempt(on model: AIModelRoute) async throws -> String {
                let session = self.session(on: model, instructions: instructions, transformsText: true)
                let prompt = ScriptPromptBuilder.rewritePrompt(for: part, tool: tool, context: context, part: details)
                let response = try await self.answering { try await session.respond(to: prompt).content }
                let rewritten = ScriptPromptBuilder.clean(response)
                guard !rewritten.isEmpty else { throw ScriptAIError.emptyResponse }
                try Self.requireLanguage(expected, in: rewritten)
                return rewritten
            }
            return try await self.withFallback(plan, operation: operation, language: language) { model in
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
        return try await RewriteRunner.run(text, tool: tool, context: context, ask: ask)
    }

    func hooks(for text: String, context: RewriteContext) async throws -> [String] {
        beginForeground()
        defer { endForeground() }
        let plan = try await plan(for: .hooks, languages: context.sourceLanguage.map { [$0] } ?? [])
        return try await withFallback(plan, operation: "hooks", language: context.sourceLanguage?.minimalIdentifier) { model in
            let session = self.session(on: model, instructions: ScriptPromptBuilder.rewriteInstructions(voice: context.voice))
            let prompt = ScriptPromptBuilder.hooksPrompt(for: text, context: context)
            let ideas = try await self.answering { try await session.respond(to: prompt, generating: HookIdeas.self).content }
            let hooks = ideas.hooks.map(ScriptPromptBuilder.cleanTitle).filter { !$0.isEmpty }
            guard !hooks.isEmpty else { throw ScriptAIError.emptyResponse }
            try Self.requireLanguage(context.sourceLanguage, in: hooks.joined(separator: " "))
            return Array(hooks.prefix(3))
        }
    }

    func suggestIdeas(about topics: [IdeaTopic], language: CueLanguage?, voice: CreatorVoice?, avoiding: [String], round: Int) async throws -> [ThemeIdea] {
        guard !topics.isEmpty else { return try await themeIdeas(for: [], language: language, voice: voice) }
        beginForeground()
        defer { endForeground() }
        let plan = try await plan(for: .themes, languages: language.map { [$0.locale.language] } ?? [])
        let known = avoiding.map(IdeaSimilarity.words(in:))
        let angles = IdeaAngle.batch(round: round)
        return try await withFallback(plan, operation: "themes", language: language?.locale.identifier) { model in
            let session = self.session(on: model, instructions: ScriptPromptBuilder.themesInstructions(voice: voice))
            let prompt = ScriptPromptBuilder.themesPrompt(about: topics, voice: voice, language: language, round: round)
            // A creative task: the idea is the point, not the one answer the model is surest of.
            let options = GenerationOptions(temperature: 1.0)
            let suggestions = try await self.answering { try await session.respond(to: prompt, generating: ThemeSuggestions.self, options: options).content }
            var seen = known
            var ideas: [ThemeIdea] = []
            for (index, idea) in suggestions.ideas.enumerated() {
                let title = ScriptPromptBuilder.cleanTitle(idea.title)
                let words = IdeaSimilarity.words(in: title)
                guard !title.isEmpty, !seen.contains(where: { IdeaSimilarity.areAlike($0, words) }) else { continue }
                seen.append(words)
                // The slot says the angle and the topic; the model's own label for either is not trusted.
                let topic = IdeaAngle.topic(at: index, round: round, among: topics) ?? topics[0]
                ideas.append(ThemeIdea(
                    title: title, kind: index < angles.count ? angles[index].kind : idea.kind.capitalized, length: idea.minutes >= 2 ? .minutes2 : .minute1,
                    niche: topic.niche ?? .lifestyle, topic: topic.niche == nil ? topic.label : nil
                ))
            }
            guard !ideas.isEmpty else { throw ScriptAIError.emptyResponse }
            return ideas
        }
    }

    func themeIdeas(for niches: [Niche], language: CueLanguage?, voice: CreatorVoice?) async throws -> [ThemeIdea] {
        beginForeground()
        defer { endForeground() }
        let plan = try await plan(for: .themes, languages: language.map { [$0.locale.language] } ?? [])
        let known = niches.isEmpty ? [Niche.lifestyle] : niches
        return try await withFallback(plan, operation: "themes", language: language?.locale.identifier) { model in
            let session = self.session(on: model, instructions: ScriptPromptBuilder.themesInstructions(voice: voice))
            let prompt = ScriptPromptBuilder.themesPrompt(for: known, voice: voice, language: language)
            let suggestions = try await self.answering { try await session.respond(to: prompt, generating: ThemeSuggestions.self).content }
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
        guard !topics.isEmpty, capabilities.deviceStatus == .available, !isBusyForeground else { return nil }
        if let language = LanguageDetector.dominantLanguage(in: text), !capabilities.deviceSupports(Self.locale(for: language)) { return nil }
        let prompt = "Topics: \(topics.joined(separator: " | "))\n\nScript:\n\(text.prefix(1500))"
        // Filing a script is never worth making a script wait: it runs behind whatever the creator asked for, is cancelled when they ask for
        // something (`beginForeground`), and is given up on after a few seconds.
        let id = UUID()
        let work = Task { () -> String? in
            let session = LanguageModelSession(
                model: SystemLanguageModel.default,
                instructions: "You file a creator's video script under one of their topics. Answer with one topic exactly as given, or none."
            )
            return try? await session.respond(to: prompt, generating: TopicChoice.self).content.topic
        }
        backgroundWork[id] = work
        let watchdog = Task {
            try? await Task.sleep(for: Self.topicLimit)
            work.cancel()
        }
        defer {
            watchdog.cancel()
            backgroundWork[id] = nil
        }
        let choice = await withTaskCancellationHandler { await work.value } onCancel: { work.cancel() }
        guard let choice else { return nil }
        return topics.first { $0.caseInsensitiveCompare(choice.trimmingCharacters(in: .whitespacesAndNewlines)) == .orderedSame }
    }

    // MARK: - What waits for what

    /// Requests the creator is waiting for (a script, a rewrite, hooks, ideas) are under way: the work that can wait (filing scripts under topics) stands
    /// aside. Measured on an iPhone 15 Pro: the arrow created a script, which started the filing of older ones on the same model, and the script waited
    /// behind them with nothing to show for it.
    var isBusyForeground: Bool { foregroundRequests > 0 }

    private func beginForeground() {
        foregroundRequests += 1
        for work in backgroundWork.values { work.cancel() }
    }

    private func endForeground() {
        foregroundRequests = max(0, foregroundRequests - 1)
    }

    /// How long filing a script under a topic may take.
    private static let topicLimit: Duration = .seconds(15)
    /// How long a request that answers in one piece (a rewrite, hooks, ideas) may take before the creator is told.
    static var singleAnswerLimit: Duration = .seconds(90)

    /// A request that answers in one piece, given up on (`ScriptAIError.timedOut`) when the model never does.
    func answering<T: Sendable>(_ work: @escaping @MainActor () async throws -> T) async throws -> T {
        let limit = Self.singleAnswerLimit
        let task = Task { try await work() }
        let flag = TimeoutFlag()
        let watchdog = Task {
            try? await Task.sleep(for: limit)
            if !Task.isCancelled {
                flag.isSet = true
                task.cancel()
            }
        }
        defer { watchdog.cancel() }
        do {
            return try await withTaskCancellationHandler { try await task.value } onCancel: { task.cancel() }
        } catch {
            if flag.isSet, !Task.isCancelled { throw ScriptAIError.timedOut }
            throw error
        }
    }

    /// Set by the watchdog of `answering` when it gave up.
    @MainActor
    private final class TimeoutFlag {
        var isSet = false
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

    /// - Parameter transformsText: the model is only changing words the creator wrote (a rewrite, a translation). The framework has guardrails made for
    ///   exactly that, which don't treat the creator's own words as a request: measured on an iPhone 15 Pro, the default ones refused a script about
    ///   cold showers ("May contain unsafe content") when asked to fit it to the length of a platform.
    func session(on model: AIModelRoute, instructions: String, transformsText: Bool = false) -> LanguageModelSession {
        if model == .privateCloud, let privateCloud {
            return LanguageModelSession(model: privateCloud, instructions: instructions)
        }
        let device = transformsText ? SystemLanguageModel(guardrails: .permissiveContentTransformations) : SystemLanguageModel.default
        return LanguageModelSession(model: device, instructions: instructions)
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
        case .declined: ScriptAIError.declined
        case .cloudUnreachable, .other: error
        }
    }

    /// Why the last answer was empty, for the console and the device measurements (never shown, never the creator's words).
    nonisolated(unsafe) static var lastEmptyReason: String?

    private static func noteEmpty(_ reason: String) {
        lastEmptyReason = reason
        Logger(subsystem: "studio.cue", category: "ScriptAI").notice("Empty answer: \(reason, privacy: .public)")
    }

    /// Tokens the answer may take: three a word of the longest script the request asks the model for (more than the platform's own, `askedWords`), and
    /// room for the structure around it. Cut short, a script written for the doubled ask came back with its last block unfinished.
    static func responseTokens(for request: ScriptRequest) -> Int {
        let words = ScriptPromptBuilder.askedRange(for: request.targetRange).high
        return min(1_800, max(600, words * 3 + 350))
    }

    /// The script out of an answer that stopped before it was complete: needs at least two blocks with text and half
    /// the words asked for (or one block with most of them), and not more than twice what was asked, so a few lines before a failure, or a block that
    /// ran on, are never passed off as a script.
    static func rescued(_ partial: ScriptDraft.PartiallyGenerated?, request: ScriptRequest) -> ScriptDraft? {
        guard let partial else { return nil }
        let blocks = (partial.blocks ?? []).compactMap { block -> ScriptDraft.Block? in
            guard let text = block.text?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty else { return nil }
            return ScriptDraft.Block(label: block.label ?? "", text: text)
        }
        let words = blocks.reduce(0) { $0 + ReadTime.wordCount(in: CueParser.stripCues($1.text)) }
        let low = ReadTime.words(for: request.targetRange.lowerBound)
        let high = ScriptPromptBuilder.askedRange(for: request.targetRange).high
        guard words >= max(15, low / 2), words <= high * 2 else { return nil }
        // One block alone is a script only when it holds most of one: measured on an iPhone 15 Pro the model sometimes put the whole script in its first
        // block and stopped (103 to 120 words), and sometimes ran on in it without end (more than a thousand), which is not one.
        guard blocks.count >= 2 || Double(words) >= Double(low) * 0.7 else { return nil }
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
    static func requireLanguage(_ expected: Locale.Language?, in text: String) throws {
        guard let expected, !OutputLanguageCheck.isPlausible(text, in: expected) else { return }
        throw ScriptAIError.wrongLanguage
    }
}
