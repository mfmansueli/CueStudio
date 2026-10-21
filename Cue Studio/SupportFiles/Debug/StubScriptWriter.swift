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
    /// How long a batch of ideas takes (`-uiTestIdeasSlow`): Find inspiration's waiting states are seen with it.
    let ideasDelay: Duration?
    /// Every batch of ideas fails (`-uiTestIdeasFail`): "Couldn't get new ideas · Try again".
    let ideasFail: Bool
    /// A script well past a minute and a half (`-uiTestLongScript`): how the page writes, follows and settles a long one.
    let writesLong: Bool

    init(available: Bool, stalls: Bool = false, ideasDelay: Duration? = nil, ideasFail: Bool = false, writesLong: Bool = false) {
        self.stalls = stalls
        self.writesLong = writesLong
        self.ideasDelay = ideasDelay
        self.ideasFail = ideasFail
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
                text: writesLong ? Self.longScript : "[confident] Let's talk about this. [pause]\n\nHere's the short version.\n\nSave this for later. [look at camera]",
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

    /// About 280 words in eight paragraphs, with cues: well past a minute and a half at the natural pace.
    private static let longScript: String = {
        let paragraph = "I tried waking up an hour earlier for thirty days, and the first week was honestly rough. [pause] "
            + "My coffee got stronger, my patience got shorter, and my phone kept pulling me back into bed with one more scroll. "
            + "Then something small changed the whole thing. [smile]"
        return (1...8).map { "\($0). " + paragraph }.joined(separator: "\n\n")
    }()

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

    /// One idea for each slot, numbered as they come, so that "another idea" can be walked through: each a whole brief (a title, the angle, an
    /// opening line) that says its slot's topic, so Find inspiration's cards read like the model's.
    func suggestIdeas(slots: [IdeaSlot], language: CueLanguage?, voice: CreatorVoice?, inspiration: [String]) async throws -> [ThemeIdea] {
        guard availability.isAvailable else { throw ScriptAIError.modelUnavailable(availability.reason ?? "") }
        if let ideasDelay { try await Task.sleep(for: ideasDelay) }
        if ideasFail { throw ScriptAIError.emptyResponse }
        suggestionCount += 1
        let words = Self.stubWords
        let answers = slots.indices.map { index in
            // Titles that differ in a word, and angles and opening lines made of words no other idea of a few batches has, so that the card does not
            // take them for one idea said again (`IdeaSimilarity.repeats` compares all three).
            let number = (suggestionCount - 1) * 6 + index
            func word(_ offset: Int) -> String { words[(number + offset) % words.count] }
            return IdeaBriefReader.Answer(
                title: "Stub \(word(0))", angle: "\(word(5).capitalized) \(word(6)) \(word(9)).",
                openingLine: "\(word(14).capitalized) \(word(16)) \(word(21))."
            )
        }
        return IdeaBriefReader.ideas(from: answers, slots: slots, language: language?.locale.language.minimalIdentifier)
    }

    func themeIdeas(for niches: [Niche], language: CueLanguage?, voice: CreatorVoice?) async throws -> [ThemeIdea] {
        guard availability.isAvailable else { throw ScriptAIError.modelUnavailable(availability.reason ?? "") }
        return [ThemeIdea(title: "A stub idea for testing", kind: "List", length: .minute1, niche: niches.first ?? .lifestyle)]
    }
}
#endif
