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
        // A serious statement takes no style, but the voice's rules hold (`ScriptRequest.rules`; the owner's B9).
        if voice == nil, let rules = request.rules {
            let lines = VoiceBriefBuilder.restrictionLines(for: rules, register: PlatformRegister(request.platform))
            sections.append("The creator's rules (they hold; not a new request):\n\(lines.joined(separator: "\n"))")
        }
        if let inspiration { sections.append(inspiration) }
        if let brand = request.brand { sections.append(ScriptPromptBuilder.brandLines(brand).joined(separator: "\n")) }
        if let literal { sections.append(literal) }
        sections.append(currentRequest)
        return sections
    }

    /// Language, platform, format and length, one line each.
    private var setting: String {
        var lines = [languageLine]
        // Gender agreement and the form of address (the owner's B8; §11.7), as Apple Intelligence gets them.
        let theirs = request.voice ?? request.rules
        lines += AgreementGuide.lines(for: theirs?.agreement, speaksAs: theirs?.resolvedSpeaksAs ?? .i, language: AgreementGuide.code(of: request))
        lines.append("Platform: \(request.platform.promptName).")
        if PlatformRegister(request.platform) == .professional { lines.append("Register: professional (no slang, no swearing, no emojis).") }
        lines.append(formatLine)
        if request.structure.isSerious { lines.append(ScriptPromptBuilder.seriousRule) }
        lines.append(length.promptLine(in: request.language))
        return lines.joined(separator: "\n")
    }

    private var languageLine: String {
        guard let language = request.language else { return "Write the script in the language of the creator's request." }
        return "Write the script in \(ScriptPromptBuilder.languageName(language, variant: request.languageVariant))."
    }

    private var formatLine: String { UltraFormatGuide.line(for: request) }

    /// The idea's inspiration (Find inspiration), only what the creator's text still says of it (`ScriptRequestFactory`).
    private var inspiration: String? {
        guard let brief = request.brief else { return nil }
        var lines = ["Inspiration this idea came from (Find inspiration):"]
        if !brief.subject.isEmpty { lines += ["Subject: \(brief.subject)", Self.keptTitleLine] }
        if let topic = ScriptPromptBuilder.briefTopicRule(brief) { lines.append(topic) }
        if let angle = ScriptPromptBuilder.briefAngleRule(brief) { lines.append(angle) }
        if let opening = ScriptPromptBuilder.briefOpeningRule(brief) { lines.append(opening) }
        return lines.count > 1 ? lines.joined(separator: "\n") : nil
    }

    /// The idea's subject is its title on the card and stays the script's (`UltraScriptService`; the owner, 04/11/2026): in the blind study the
    /// creator found their idea in the title every time, against 33 to 42% when the editor wrote its own, and the scripts scored the same.
    static let keptTitleLine = "This subject stays the video's title: the script must deliver what it promises."

    /// The words the creator asked for literally ("say exactly …"): repeated as they are.
    private var literal: String? {
        let phrases = request.requiredPhrases
        guard !phrases.isEmpty else { return nil }
        return "Say these words exactly as written: " + phrases.map { "“\($0)”" }.joined(separator: "; ") + "."
    }

    /// The creator's words as they typed them (never shortened or normalized).
    private var currentRequest: String {
        switch request.source {
        case .prompt(let text):
            return "The creator's request, in their exact words:\n\"\"\"\n\(text)\n\"\"\""
        }
    }
}
