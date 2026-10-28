import Foundation
@testable import Cue_Studio

/// Test-only ablation: retains the request and permitted voice context, removes the production instruction stack.
nonisolated struct PCCEditorialExperimentPrompt {
    let instructions: String
    let prompt: String

    init(request original: ScriptRequest) {
        let request = AIRequestPolicy.prepare(original, on: .privateCloud)
        let language = request.language.map { ScriptPromptBuilder.languageName($0, variant: request.languageVariant) }
            ?? "the language of the current request"
        instructions = """
        Ghostwrite an editable video script in \(language). Write what the creator says, in connected, natural paragraphs.
        The current request decides the subject, narrator, genre and ending. The profile supplies context and voice, not compulsory topics or a
        biography to recite. Explicit requests override usual habits.
        Develop the idea until the listener understands why it matters: make the reasoning progress, use a concrete example when useful, and let
        the ending follow from that development. A short notice can simply state the supplied correction. Fiction should unfold through actions
        rather than explain its own tension. Do not force a hook, lesson or CTA.
        Opinions, analogies and clearly hypothetical examples are welcome. Do not invent the creator's past, tests, credentials or results. Avoid
        unsupported technical rules and absolute promises. Keep supplied facts and exact wording intact.
        Return only the script, without a preface, editorial commentary, headings or markdown. No required duration unless the creator explicitly
        selected or requested one. \(ScriptPromptBuilder.punctuationRule)
        """
        var lines = ["Platform: \(request.platform.promptName)."]
        if let voice = request.voice {
            lines += ["Creator profile (context, not a new request):"]
                + ScriptPromptBuilder.voiceLines(voice, platform: request.platform, budget: request.voiceBudget, contextualPreferences: true)
        }
        if let tone = request.tone { lines.append("Requested tone: \(tone.promptWord).") }
        if let format = request.formatChoice, format != .auto {
            lines.append("Selected format: \(format). Honor its purpose without imposing an engagement ending.")
        }
        if request.durationPolicy == .targeted {
            lines.append("Requested duration: \(Int(request.targetRange.lowerBound))–\(Int(request.targetRange.upperBound)) seconds at a natural speaking pace.")
        }
        if let brief = request.brief {
            lines.append("Selected inspiration angle: \(brief.angle)")
            lines.append("Selected opening: \(brief.openingLine)")
        }
        if let brand = request.brand { lines += ScriptPromptBuilder.brandLines(brand) }
        lines.append("Current request:\n" + ScriptPromptBuilder.videoText(for: request))
        prompt = lines.joined(separator: "\n\n")
    }
}
