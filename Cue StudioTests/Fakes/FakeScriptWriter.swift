//
//  FakeScriptWriter.swift
//  Cue StudioTests
//

import Foundation
@testable import Cue_Studio

@MainActor
final class FakeScriptWriter: ScriptWriting {
    var isEnabled = true
    var availability = AIAvailability(onDevice: true, privateCloud: true, reason: nil)
    var generatedText = "Hey there. [pause]\n\nThis is the body.\n\nFollow for more."
    var generatedTitle = "Generated title"
    var statesFacts = false
    var rewrittenText = "Rewritten with energy!"
    var hookIdeas = ["New hook one.", "New hook two.", "New hook three."]
    var ideas: [ThemeIdea] = []
    var error: Error?
    /// Set, the writer says it can't write the request's languages (what the real one decides from the model).
    var writingFailureToReturn: AIPlanFailure?
    /// Languages (ISO codes) the model doesn't write: a request that asks one of them is told so, the way the planner does.
    var languagesNotWritten: Set<String> = []
    private(set) var lastRequest: ScriptRequest?
    private(set) var lastRewrite: (tool: ScriptTool, context: RewriteContext)?
    private(set) var hooksRequested = 0
    /// A request the creator is waiting for is under way (topic filing stands aside).
    var isBusyForeground = false
    /// The topic the model files a script under; nil is "none fits".
    var topicToPick: String?
    private(set) var topicsAsked = 0
    /// The voice the last request for ideas carried.
    private(set) var lastThemeVoice: CreatorVoice?
    /// What the writer tells the page's meter before it answers.
    var eventsToReport: [ScriptWritingEvent] = []
    /// The meter the last script was written with.
    private(set) var lastMeter: WritingProgressMeter?
    /// What `suggestIdeas` answers, one batch for each request (the last one again when they run out); empty: the fake `ideas`.
    var suggestionBatches: [[ThemeIdea]] = []
    private(set) var suggestionRequests: [(slots: [IdeaSlot], inspiration: [String])] = []
    /// How each request for ideas was asked (a prefetch, or the creator waiting).
    private(set) var suggestionPriorities: [IdeaRequestPriority] = []
    /// Set, a request for ideas waits until it is false again (or is cancelled): a model still writing.
    var holdsSuggestions = false
    /// Requests for ideas that were cancelled while they waited.
    private(set) var cancelledSuggestions = 0
    private var interruptsSuggestions = false

    /// A script begins, as on the real writer (`beginForeground`): the creator waits for it, and ideas being written stand aside.
    func beginScript() {
        isBusyForeground = true
        interruptsSuggestions = true
    }

    func endScript() {
        isBusyForeground = false
        interruptsSuggestions = false
    }

    var isAvailable: Bool {
        get { availability.isAvailable }
        set { availability = newValue ? AIAvailability(onDevice: true, privateCloud: true, reason: nil) : .unavailable }
    }

    func writingFailure(in languages: [Locale.Language]) -> AIPlanFailure? {
        if let writingFailureToReturn { return writingFailureToReturn }
        let missing = languages.first { languagesNotWritten.contains($0.languageCode?.identifier ?? "") }
        return missing.map { .unsupportedLanguage($0) }
    }

    func generate(_ request: ScriptRequest) async throws -> GeneratedScript {
        if let error { throw error }
        lastRequest = request
        switch request.source {
        case .prompt:
            guard availability.isAvailable else { throw ScriptAIError.modelUnavailable(availability.reason ?? "") }
            return GeneratedScript(
                title: generatedTitle, text: generatedText, usedLanguageModel: true,
                needsFactCheck: request.isFactualTopic || statesFacts, model: .privateCloud
            )
        case .format(let type, let brief):
            if availability.isAvailable {
                return GeneratedScript(title: type.draftTitle(from: brief), text: generatedText, usedLanguageModel: true, model: .onDevice)
            }
            return GeneratedScript(title: type.draftTitle(from: brief), text: type.draft(from: brief), usedLanguageModel: false)
        }
    }

    func generate(_ request: ScriptRequest, reporting meter: WritingProgressMeter?) async throws -> GeneratedScript {
        lastMeter = meter
        for event in eventsToReport { meter?.record(event) }
        return try await generate(request)
    }

    func rewrite(_ text: String, with tool: ScriptTool, context: RewriteContext) async throws -> String {
        if let error { throw error }
        guard availability.isAvailable else { throw ScriptAIError.modelUnavailable(availability.reason ?? "") }
        lastRewrite = (tool, context)
        return rewrittenText
    }

    func hooks(for text: String, context: RewriteContext) async throws -> [String] {
        if let error { throw error }
        guard availability.isAvailable else { throw ScriptAIError.modelUnavailable(availability.reason ?? "") }
        hooksRequested += 1
        return hookIdeas
    }

    func themeIdeas(for niches: [Niche], language: CueLanguage?, voice: CreatorVoice?) async throws -> [ThemeIdea] {
        lastThemeVoice = voice
        if let error { throw error }
        guard availability.isAvailable else { throw ScriptAIError.modelUnavailable(availability.reason ?? "") }
        return ideas
    }

    func suggestIdeas(slots: [IdeaSlot], language: CueLanguage?, voice: CreatorVoice?, inspiration: [String]) async throws -> [ThemeIdea] {
        try await suggestIdeas(slots: slots, language: language, voice: voice, inspiration: inspiration, priority: .waiting)
    }

    /// As the real writer: a prefetch is refused while the creator waits for something else.
    func suggestIdeas(
        slots: [IdeaSlot], language: CueLanguage?, voice: CreatorVoice?, inspiration: [String], priority: IdeaRequestPriority
    ) async throws -> [ThemeIdea] {
        if priority == .prefetch, isBusyForeground { throw CancellationError() }
        suggestionRequests.append((slots, inspiration))
        suggestionPriorities.append(priority)
        do {
            while holdsSuggestions {
                if interruptsSuggestions { throw CancellationError() }
                try await Task.sleep(for: .milliseconds(5))
            }
        } catch {
            cancelledSuggestions += 1
            throw error
        }
        lastThemeVoice = voice
        if let error { throw error }
        guard availability.isAvailable else { throw ScriptAIError.modelUnavailable(availability.reason ?? "") }
        guard !suggestionBatches.isEmpty else { return ideas }
        return suggestionBatches[min(suggestionRequests.count - 1, suggestionBatches.count - 1)]
    }

    func pickTopic(for text: String, among topics: [String]) async -> String? {
        topicsAsked += 1
        return topicToPick
    }
}
