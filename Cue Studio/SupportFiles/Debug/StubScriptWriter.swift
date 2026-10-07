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

    var isEnabled = true
    private var suggestionCount = 0
    private static let stubWords = [
        "alpha", "bravo", "charlie", "delta", "echo", "foxtrot", "golf", "hotel", "india", "juliet", "kilo", "lima", "mike", "november", "oscar", "papa",
        "quebec", "romeo", "sierra", "tango", "uniform", "victor", "whiskey", "xray", "yankee", "zulu", "amber", "birch", "cedar", "dune", "ember", "frost",
    ]
    /// The model never answers (until the request is cancelled): the slow states of the first message are photographed with it.
    let stalls: Bool

    init(available: Bool, stalls: Bool = false) {
        self.stalls = stalls
        availability = available
            ? AIAvailability(onDevice: true, privateCloud: true, reason: nil)
            : .unavailable
    }

    func generate(_ request: ScriptRequest) async throws -> GeneratedScript {
        if stalls { try await Task.sleep(for: .seconds(3600)) }
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
            return GeneratedScript(
                title: type.draftTitle(from: brief), text: type.draft(from: brief),
                usedLanguageModel: availability.isAvailable, model: .onDevice
            )
        }
    }

    /// Stalling, the words still come in, six every 0.4 s, and the script never ends: the star's percentage moves while it waits.
    func generate(_ request: ScriptRequest, reporting meter: WritingProgressMeter?) async throws -> GeneratedScript {
        guard stalls, let meter else { return try await generate(request) }
        meter.record(.drafting)
        var words = 0
        while true {
            try await Task.sleep(for: .milliseconds(400))
            words += 6
            meter.record(.wrote(words: words))
        }
    }

    func rewrite(_ text: String, with tool: ScriptTool, context: RewriteContext) async throws -> String {
        guard availability.isAvailable else { throw ScriptAIError.modelUnavailable(availability.reason ?? "") }
        // Each tool leaves its own mark, so a test can tell which button did what.
        return text + "\n\n[smile] Rewritten with \(tool.rawValue)."
    }

    func hooks(for text: String, context: RewriteContext) async throws -> [String] {
        guard availability.isAvailable else { throw ScriptAIError.modelUnavailable(availability.reason ?? "") }
        return ["Stub hook one.", "Stub hook two.", "Stub hook three."]
    }

    /// One idea for each slot, numbered as they come, so that "another idea" can be walked through.
    func suggestIdeas(slots: [IdeaSlot], language: CueLanguage?, voice: CreatorVoice?, inspiration: [String]) async throws -> [ThemeIdea] {
        guard availability.isAvailable else { throw ScriptAIError.modelUnavailable(availability.reason ?? "") }
        suggestionCount += 1
        return slots.enumerated().map { index, slot in
            // Titles that differ in a word, so that the card does not take them for one idea said again (`IdeaSimilarity`).
            let word = Self.stubWords[((suggestionCount - 1) * 6 + index) % Self.stubWords.count]
            var idea = ThemeIdea(
                title: "Stub \(word)", kind: slot.angle.kind, length: .minute1, niche: slot.topic.niche ?? .lifestyle,
                topic: slot.topic.niche == nil ? slot.topic.label : nil
            )
            idea.angle = slot.angle.rawValue
            return idea
        }
    }

    func themeIdeas(for niches: [Niche], language: CueLanguage?, voice: CreatorVoice?) async throws -> [ThemeIdea] {
        guard availability.isAvailable else { throw ScriptAIError.modelUnavailable(availability.reason ?? "") }
        return [ThemeIdea(title: "A stub idea for testing", kind: "List", length: .minute1, niche: niches.first ?? .lifestyle)]
    }
}
#endif
