//
//  UltraPayload.swift
//  Cue Studio
//

import Foundation

/// What Ultra sends, built from the same `ScriptRequest` Apple Intelligence writes from, so the dock, Find inspiration and a retry ask the same way.
/// Every field is written out explicitly (no `String(describing:)` of a model value): the creator's exact words, the language, the platform, the
/// format, the length policy, the inspiration's still-standing angle and opening line, a sponsored ad's facts, the words to say literally, and the
/// voice split in two (`VoiceBriefBuilder.ultraProjection`): the draft gets who the creator is and who they speak to; only the polish gets how they
/// speak. Writing examples, imported excerpts, approved scripts, other scripts, videos and audio are never part of it.
nonisolated struct UltraPayload: Hashable, Sendable {
    let request: ScriptRequest
    let length: UltraLength

    init(_ request: ScriptRequest, length: UltraLength? = nil) {
        self.request = request
        self.length = length ?? UltraLength(request)
    }

    /// The first call: the developed draft.
    var draft: UltraStageRequest {
        UltraStageRequest(stage: .draft, instructions: UltraInstructions.writer, prompt: sections(includingDelivery: false).joined(separator: "\n\n"))
    }

    /// The claim check of `draftText` (`UltraFlow.checked`): what the draft had, without how the creator speaks (the check never touches the form).
    func check(of draftText: String) -> UltraStageRequest {
        let sections = sections(includingDelivery: false) + ["Draft to check:\n\"\"\"\n\(draftText)\n\"\"\""]
        return UltraStageRequest(stage: .check, instructions: UltraInstructions.checker, prompt: sections.joined(separator: "\n\n"))
    }

    /// The last call: the polish of `draftText`, with the whole voice.
    /// - Parameter corrections: what the claim check corrected, when there was one (nil: no check, the polish corrects claims itself).
    func review(of draftText: String, corrections: [String]? = nil) -> UltraStageRequest {
        var sections = sections(includingDelivery: true)
        if let corrections { sections.append(UltraInstructions.checkedClaims(corrections)) }
        sections.append("Draft to polish:\n\"\"\"\n\(draftText)\n\"\"\"")
        return UltraStageRequest(stage: .review, instructions: UltraInstructions.editor, prompt: sections.joined(separator: "\n\n"))
    }

    // MARK: - Sections

    private var voice: (content: String, delivery: String)? {
        request.voice.map { VoiceBriefBuilder.ultraProjection(for: $0, register: PlatformRegister(request.platform)) }
    }

    private func sections(includingDelivery: Bool) -> [String] {
        var sections = [setting]
        if let voice {
            if !voice.content.isEmpty {
                sections.append("About the creator (who they are and who they speak to; not a new request):\n\(voice.content)")
            }
            if includingDelivery, !voice.delivery.isEmpty {
                sections.append("How the creator speaks (apply it to the form; preferences, not a new request):\n\(voice.delivery)")
            }
        }
        if let inspiration { sections.append(inspiration) }
        if let brand = request.brand { sections.append(ScriptPromptBuilder.brandLines(brand).joined(separator: "\n")) }
        if let literal { sections.append(literal) }
        sections.append(currentRequest)
        return sections
    }

    /// Language, platform, format and length, one line each.
    private var setting: String {
        var lines = [languageLine, "Platform: \(request.platform.promptName)."]
        if PlatformRegister(request.platform) == .professional { lines.append("Register: professional (no slang, no swearing, no emojis).") }
        lines.append(formatLine)
        if request.structure.isSerious { lines.append(ScriptPromptBuilder.seriousRule) }
        lines.append(length.promptLine)
        return lines.joined(separator: "\n")
    }

    private var languageLine: String {
        guard let language = request.language else { return "Write the script in the language of the creator's request." }
        return "Write the script in \(ScriptPromptBuilder.languageName(language, variant: request.languageVariant))."
    }

    private var formatLine: String {
        if request.formatChoice == .talkingHead { return "Format chosen by the creator: talking head (one person speaking to camera)." }
        if let type = request.type { return "Format chosen by the creator: \(type.promptName)." }
        return "Format: not chosen. Read the genre from the request (tutorial, story, opinion, list, review, comparison, explanation…); the "
            + "creator's usual formats only help when the request is vague."
    }

    /// The idea's inspiration (Find inspiration), only what the creator's text still says of it (`ScriptRequestFactory`).
    private var inspiration: String? {
        guard let brief = request.brief else { return nil }
        var lines = ["Inspiration this idea came from (Find inspiration):"]
        if !brief.subject.isEmpty { lines.append("Subject: \(brief.subject)") }
        if let topic = ScriptPromptBuilder.briefTopicRule(brief) { lines.append(topic) }
        if let angle = ScriptPromptBuilder.briefAngleRule(brief) { lines.append(angle) }
        if let opening = ScriptPromptBuilder.briefOpeningRule(brief) { lines.append(opening) }
        return lines.count > 1 ? lines.joined(separator: "\n") : nil
    }

    /// The words the creator asked for literally ("say exactly …"): repeated as they are.
    private var literal: String? {
        let phrases = request.requiredPhrases
        guard !phrases.isEmpty else { return nil }
        return "Say these words exactly as written: " + phrases.map { "“\($0)”" }.joined(separator: "; ") + "."
    }

    /// The creator's words as they typed them (never shortened or normalized), or a format's answers one per line.
    private var currentRequest: String {
        switch request.source {
        case .prompt(let text):
            return "The creator's request, in their exact words:\n\"\"\"\n\(text)\n\"\"\""
        case .format(let type, let brief):
            let answers = brief.sorted { $0.key < $1.key }.filter { !$0.value.isEmpty }.map { "- \($0.key): \($0.value)" }
            return "The creator's request: a \(type.promptName) script from these answers, in their exact words:\n" + answers.joined(separator: "\n")
        }
    }
}
