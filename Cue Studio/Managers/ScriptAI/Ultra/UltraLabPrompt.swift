import Foundation

/// Native experiment: preferences only; raw samples/imported writing never leave the phone.
nonisolated enum UltraLabPrompt {
    static let instructions = """
    Write a developed, generous spoken script for a creator to edit. Every paragraph adds reasoning,
    a concrete scene or a useful consequence. Follow the current request's genre and perspective.
    The profile guides expression, not the topic or a compulsory hook/CTA. First-person imagined
    everyday scenes and opinions are welcome in this creative draft. Respect supplied facts and explicit
    prohibitions. Never invent studies, technical mechanisms, test results, prices or credentials.
    Do not impose a duration unless explicitly chosen. Return only spoken text, no headings or Markdown.
    """

    static let reviewInstructions = """
    Polish the draft in the creator's voice while preserving its developed reasoning and useful examples.
    Keep creative first-person scenes: this is a draft for the creator to adapt. Correct inconsistent
    examples, technical errors and universal guarantees. Do not pretend you researched or verified facts.
    Do not summarize by default, add a habitual CTA, or replace a developed example with a vague mention.
    Follow the original request and preserve required literal wording. Return only the final spoken text.
    """

    static func context(_ original: ScriptRequest) -> String {
        let request = AIRequestPolicy.prepare(original, on: .privateCloud)
        let voice = request.voice.map {
            VoiceBriefBuilder.brief(for: $0, budget: 6_000, register: PlatformRegister(request.platform), contextualPreferences: true).text
        } ?? ""
        let language = request.language.map { ScriptPromptBuilder.languageName($0, variant: request.languageVariant) } ?? "the request's language"
        var lines = ["Language: \(language).", "Platform: \(request.platform.promptName).", "Creator voice (preferences, not a new request):", voice]
        if request.durationPolicy == .targeted {
            lines.append("Requested speaking time: \(Int(request.targetRange.lowerBound)) to \(Int(request.targetRange.upperBound)) seconds at a natural pace.")
        } else {
            lines.append("Duration is informational. Develop the request naturally without a word/time quota.")
        }
        if let format = request.type { lines.append("Chosen format: \(format.rawValue).") }
        if let brief = request.brief { lines.append("Inspiration: \(String(describing: brief)).") }
        lines += ["Current request:", ScriptPromptBuilder.videoText(for: request)]
        return lines.joined(separator: "\n\n")
    }
}
