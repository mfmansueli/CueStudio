//
//  ScriptPromptBuilder.swift
//  Cue Studio
//

import Foundation

/// Builds instructions and prompts for the on-device model, and cleans what comes back. Pure text,
/// so it can be tested without the model.
nonisolated enum ScriptPromptBuilder {
    static let cueHint = "Add short stage cues in square brackets where they help delivery, like [pause], [smile] or [look at camera]. Never put spoken words inside brackets."

    // MARK: - Generation

    static func instructions(for request: ScriptRequest, insistsOnLanguage: Bool = false) -> String {
        let structure = request.structure
        let voice = structure.isSerious ? nil : request.voice
        var lines = [
            "You write short-form video scripts that a creator reads from a teleprompter while filming themselves.",
            "Write in the first person, as the creator, in natural spoken language\(sentenceClause(for: voice)).",
            "Fill in a short title and the script blocks. Block text is only what the creator says: no headings, labels, markdown or quotes around it.",
            cueHint,
        ]
        if structure.isSerious {
            lines.append(seriousRule)
        } else {
            // Where it is posted shapes the hook, the pace and the ending; a serious statement has none of those.
            lines.append(PlatformGuide.line(for: request.platform))
            lines.append(honestyRule)
        }
        if request.isFreePrompt {
            lines.append(accuracyRule)
        }
        if let voice {
            lines += voiceLines(voice, platform: request.platform)
        }
        if let language = request.language {
            lines.append(languageRule(language, variant: request.languageVariant))
            if insistsOnLanguage || language != .english { lines.append(languageInsistence(language, variant: request.languageVariant)) }
        }
        return lines.joined(separator: "\n")
    }

    /// How long the sentences are, as the creator chose; short is what a teleprompter reads best when they didn't say.
    static func sentenceClause(for voice: CreatorVoice?) -> String {
        switch voice?.style.sentences {
        case .long?: " with longer, flowing sentences"
        case .mixed?: " with a mix of short and longer sentences"
        case .short?, nil: " with short sentences"
        }
    }

    /// Which language to write in, named in English so the rule reads the same whatever the
    /// interface language is.
    static func languageRule(_ language: CueLanguage, variant: Locale? = nil) -> String {
        "Write the title and every block in \(languageName(language, variant: variant))."
    }

    /// For a language other than English the instructions themselves are in English, and a catchphrase in the
    /// voice may be too: the model has answered in English (measured: a Japanese idea, an English "Hey fam").
    static func languageInsistence(_ language: CueLanguage, variant: Locale? = nil) -> String {
        let name = languageName(language, variant: variant)
        return "The script is in \(name), not in English: write it in \(name) even though these instructions are in English. Only the creator's catchphrases stay as they are."
    }

    /// "English (United Kingdom)" for the creator's own variant, "English" for the language Cue offers.
    static func languageName(_ language: CueLanguage, variant: Locale? = nil) -> String {
        guard let variant, let name = Locale(identifier: "en").localizedString(forIdentifier: variant.identifier) else {
            return language.englishName
        }
        return name
    }

    /// How many times the words a short script needs the model is asked to write. Measured on an iPhone 15 Pro (iOS 27, TikTok, three ideas): asked for
    /// 150 to 225 words the model wrote 64 to 105 (54 when the retry was told its draft was short), asked for 240 to 360 it wrote 122 to 206, asked
    /// for 330 to 495 it wrote 130 to 216. It writes about half of what it is asked, and goes on writing less than asked however it is told (a count
    /// of sentences for every block and the draft to expand were tried: 64 to 86 words). So the request asks for more than is needed. Only the
    /// device measurement (`PlatformLengthDeviceTests`) changes it.
    nonisolated(unsafe) static var lengthAskFactor = 1.5

    /// The words to ask the model for when the script needs `words`: `lengthAskFactor` times as many for a short script, fewer times as the script gets
    /// longer (a script of 1000 words or more is asked as it is: the model already writes the 1286 words of a YouTube video, and its answer is bounded).
    static func askedWords(_ words: Int) -> Int {
        let factor = words <= 250 ? lengthAskFactor : max(1.0, lengthAskFactor - (lengthAskFactor - 1.0) * Double(words - 250) / 750)
        return Int((Double(words) * factor).rounded())
    }

    /// The words the request asks the model for when the script must run `range` seconds: the floor as `askedWords` has it, and a ceiling that is not
    /// raised with it (a Short asked for 150 to 300 words wrote 310, two minutes of a script for a video of one), only kept above the floor.
    static func askedRange(for range: ClosedRange<TimeInterval>) -> (low: Int, high: Int) {
        let low = askedWords(ReadTime.words(for: range.lowerBound))
        return (low, max(ReadTime.words(for: range.upperBound), Int((Double(low) * 1.25).rounded())))
    }

    static func prompt(for request: ScriptRequest) -> String {
        let structure = request.structure
        let (low, high) = askedRange(for: request.targetRange)
        var lines: [String] = []
        // On the iPhone 18 Pro Max the model wrote every script in English when the creator's voice (English instructions, an
        // English catchphrase) was on, whatever the instructions said: the language is also asked for in the request itself.
        if let language = request.language, language != .english || request.languageVariant != nil {
            lines.append("Language of the script: \(languageName(language, variant: request.languageVariant)). Write all of it in \(languageName(language, variant: request.languageVariant)).")
        }
        // The shape: the format the creator chose, or the one the idea asks for (only the AI is told), in English with what each block is for.
        let guide = formatGuide(for: request)
        lines += [
            "Write a \(guide.name) script for \(request.platform.promptName).",
            "Blocks, in this order: \(guide.order).",
            "What each block does: \(guide.purpose)",
        ]
        if let tone = request.tone {
            lines.append("Tone: \(tone.promptWord).")
        }
        lines.append("Length: between \(low) and \(high) spoken words in total.")
        // Measured on an iPhone: told only the range, the model wrote about a third of it (44 to 82 words for 150 to 225,
        // in every language). Naming the minimum and what a block holds helps, and so does asking for more than is needed (`askedWords`).
        lines.append(lengthRule(minimumWords: low, blocks: guide.blocks.count, sentenceWords: sentenceWords(for: request.voice)))
        let voice = structure.isSerious ? nil : request.voice
        if !structure.isSerious {
            lines.append(hookRule(for: voice))
        }
        switch request.source {
        case .prompt(let text):
            lines.append("The video: \(text)")
        case .format(let type, let brief):
            if request.brand == nil {
                let resolved = type.resolvedBrief(brief)
                lines.append("Brief:")
                lines += type.briefFields.map { "- \($0.label): \(resolved[$0.key] ?? $0.example)" }
            }
        }
        if let brand = request.brand {
            lines += brandLines(brand)
        }
        // Said again at the very end, where a small model listens best.
        if let voice, let closing = closingRule(for: voice, platform: request.platform) {
            lines.append(closing)
        }
        return lines.joined(separator: "\n")
    }

    /// The shape of the script: the chosen format, else the one a free idea asks for (or the creator films most), else the generic one.
    static func formatGuide(for request: ScriptRequest) -> FormatGuide {
        if let type = request.type { return .guide(for: type) }
        guard case .prompt(let idea) = request.source else { return .generic }
        return .guide(for: FormatGuess.format(for: idea, usual: request.voice?.formats ?? []))
    }

    /// The hook, in the creator's own way of opening when they have one.
    static func hookRule(for voice: CreatorVoice?) -> String {
        guard let voice, !voice.openings.isEmpty else { return "Open with a hook that works in the first 3 seconds." }
        return "Open with a hook that works in the first 3 seconds, in the creator's own way of opening."
    }

    /// What must hold whatever else the script does (who is talking, what to avoid), repeated after the idea; nil with nothing to repeat.
    static func closingRule(for voice: CreatorVoice, platform: Platform? = nil) -> String? {
        let rules = VoiceBriefBuilder.closingRules(for: voice, register: platform.map(PlatformRegister.init) ?? .casual)
        return rules.isEmpty ? nil : "Remember: " + rules.joined(separator: " ")
    }

    /// The note added to a request the checker sent back: what the last draft got wrong, and what it must be.
    static func correctionNote(for violations: [VoiceViolation]) -> String {
        "Your last draft broke these rules: \(violations.map(\.detail).joined(separator: " ")) Write the whole script again and follow them."
    }

    /// Words in a sentence of this creator's: what they said ("short and punchy" is nine), what was measured of their writing, else twelve.
    static func sentenceWords(for voice: CreatorVoice?) -> Int {
        if let voice {
            switch voice.style.sentences {
            case .short?: return 9
            case .long?: return 18
            default: break
            }
            if let fingerprint = voice.fingerprint, fingerprint.isReliable, !WritingLexicon.isUnspaced(fingerprint.language) {
                return min(20, max(5, Int(fingerprint.wordsPerSentence.rounded())))
            }
        }
        return 12
    }

    /// Every block gets full sentences, and the script doesn't stop before its minimum. Measured on an iPhone 15 Pro (iOS 27): told "several complete
    /// sentences" the model still wrote one or two a block, 54 words for the 150 it was asked, even on the second attempt. A count of sentences for
    /// every block is something it can follow, where a count of words in total is not.
    /// Whether the length is asked in sentences for every block (true), or in the words of the script alone (false): the device measurement compares them.
    nonisolated(unsafe) static var asksSentencesPerBlock = true

    static func lengthRule(minimumWords: Int, blocks: Int = 3, sentenceWords: Int = 12) -> String {
        guard asksSentencesPerBlock else {
            return "Do not stop early: the script must be at least \(minimumWords) words, so write every block in full, with several complete sentences each."
        }
        // A count of sentences is for a short script: asked for dozens in every block of a long one the model runs on until its answer is cut off.
        guard minimumWords <= 400 else {
            return "Do not stop early: the script must be at least \(minimumWords) words, so write every block in full, with many complete sentences each."
        }
        let sentences = Int((Double(minimumWords) / Double(max(1, sentenceWords))).rounded(.up))
        let perBlock = max(2, Int((Double(sentences) / Double(max(1, blocks))).rounded(.up)))
        return "Do not stop early: the script must be at least \(minimumWords) words, which is at least \(sentences) sentences in all. "
            + "Write at least \(perBlock) sentences in every block, and none of them cut short."
    }

    // MARK: - Voice

    /// My Cue Voice as the lines the model reads (`VoiceBriefBuilder`): who is talking, who is watching, what about, how they sound, how
    /// they open and close, examples and the rules, in at most `VoiceBrief.budget` characters.
    static func voiceLines(_ voice: CreatorVoice, platform: Platform? = nil) -> [String] {
        VoiceBriefBuilder.brief(for: voice, register: platform.map(PlatformRegister.init) ?? .casual).lines
    }

    /// "What Cue sends" (My Cue Voice): the voice as the model reads it, and what was cut to fit. Empty when nothing of the voice can be used yet.
    static func brief(for profile: CreatorProfile) -> VoiceBrief {
        guard profile.canWriteInMyVoice else { return .empty }
        return VoiceBriefBuilder.brief(for: profile.voice)
    }

    /// The text of `brief(for:)`.
    static func voiceBrief(_ profile: CreatorProfile) -> String {
        brief(for: profile).text
    }

    // MARK: - Sponsored ads

    /// The brand brief of a sponsored ad: the only things the ad may claim. Nothing is invented, and the paid
    /// partnership is always disclosed (#ad).
    static func brandLines(_ brand: BrandBrief) -> [String] {
        var lines = [
            "This is a sponsored ad. Use only the facts below. Never invent claims, results, prices, discounts or guarantees.",
            "- Brand: \(brand.name)",
            "- Product or offer: \(brand.product)",
        ]
        if !brand.mustSay.isEmpty { lines.append("- Must say: \(brand.mustSay)") }
        if !brand.neverSay.isEmpty { lines.append("- Never say or mention: \(brand.neverSay)") }
        if !brand.link.isEmpty { lines.append("- Link: \(brand.link)") }
        if !brand.code.isEmpty { lines.append("- Code: \(brand.code)") }
        lines.append("Say that this is a paid partnership (#ad) within the script.")
        return lines
    }

    static let seriousRule = "This is a serious statement. Be sincere, specific and brief. No hooks, jokes, hype, emojis or calls to follow, like or subscribe. Never write \"but\" after taking responsibility."

    /// Measured on an iPhone: scripts in the first person made up stories ("I see so many people come to me…", "my first year as a nurse").
    static let honestyRule = "Never invent personal stories, clients, results, numbers or credentials for the creator: speak from general experience unless the idea gives the details."

    static let accuracyRule = "Be accurate. State only facts you are confident about; when unsure of a date, name or number, say it more generally instead of inventing it."

    // MARK: - Hooks and ideas

    static func hooksPrompt(for text: String, context: RewriteContext) -> String {
        """
        Write three new opening lines for this script, which will be posted on \(context.platform.promptName). \
        Each must grab attention in about three seconds and lead into the rest of the script. \
        Write them in the language the script is written in.

        Script:
        \(text)
        """
    }

    /// What the model is told before it suggests ideas: who it works for, and the creator's voice when there is one (their topics, who is
    /// watching and why) so the ideas are theirs and not any creator's.
    static func themesInstructions(voice: CreatorVoice? = nil) -> String {
        var lines = ["You suggest video ideas for creators who film themselves talking to camera."]
        if let voice { lines += voiceLines(voice) }
        return lines.joined(separator: "\n")
    }

    static func themesPrompt(for niches: [Niche], voice: CreatorVoice? = nil, language: CueLanguage? = nil) -> String {
        let names = (niches.isEmpty ? [Niche.lifestyle] : niches).map(\.label).joined(separator: ", ")
        var prompt = "Suggest six fresh talking-head video ideas for a creator whose niche is: \(names). Mix the niches and the kinds of video. Use each niche name exactly as written."
        if let voice, !voice.topics.isEmpty {
            prompt += " Ideas may also be about their other topics, in the detail you were given."
        }
        if let language {
            prompt += " Write the ideas in \(language.englishName)."
        }
        return prompt
    }

    // MARK: - Rewrites

    /// - Parameter language: the language the result must be in (the script's, or a translation's target), named
    ///   outright for any language but English: the instructions are in English, and so may be a catchphrase.
    static func rewriteInstructions(voice: CreatorVoice? = nil, language: Locale.Language? = nil) -> String {
        var lines = [
            "You edit teleprompter scripts for video creators.",
            "Keep the creator's voice and first person. Keep the stage cues that are in square brackets where they are.",
            "Never add stage cues, scene descriptions, sound effects or notes of your own: only the words the creator says.",
            "Return only the full edited script: no explanations, no headings, no markdown, no quotes around it.",
            "Separate paragraphs with a blank line.",
            "Keep the script in the language it is written in, unless you are asked to translate it.",
        ]
        if let language, language.languageCode?.identifier != "en" {
            let name = Locale(identifier: "en").localizedString(forIdentifier: language.minimalIdentifier) ?? language.minimalIdentifier
            lines.append("The result is in \(name), not in English: write it in \(name) even though these instructions are in English. Only the creator's catchphrases stay as they are.")
        }
        if let voice {
            lines += voiceLines(voice)
        }
        return lines.joined(separator: "\n")
    }

    /// What a part of a longer script is told about itself, and what it was told the last time it missed.
    nonisolated struct RewritePart: Equatable, Sendable {
        /// Which part this is, from 1, of how many.
        var index = 1
        var count = 1
        /// The words the result is to have ("Fit to time", per part): a part gets its share of the whole.
        var target: ClosedRange<Int>?
        /// The paragraph before this one, for the model to read and leave out of its answer.
        var leadIn: String?
        /// What its last answer got wrong (`RewriteOutcome.correction`).
        var correction: String?
    }

    static func rewritePrompt(for text: String, tool: ScriptTool, context: RewriteContext, part: RewritePart = RewritePart()) -> String {
        var lines: [String] = []
        if tool == .fitToTime, let target = part.target {
            lines.append(fitInstruction(for: target, sourceWords: ReadTime.wordCount(in: text)))
        } else {
            lines.append(instruction(for: tool, context: context))
        }
        if part.count > 1 {
            lines.append("This is part \(part.index) of \(part.count) of a longer script. Edit only this part and answer with only this part: no introduction and no ending that is not here.")
        }
        if let leadIn = part.leadIn {
            lines.append("For context, the paragraph before it (leave it out of your answer):\n\(leadIn)")
        }
        if let correction = part.correction { lines.append(correction) }
        return lines.joined(separator: "\n\n") + "\n\nScript:\n\(text)"
    }

    /// "Fit to time" for a part: the words it is to have, and how to get there.
    static func fitInstruction(for target: ClosedRange<Int>, sourceWords: Int) -> String {
        let how = sourceWords > target.upperBound
            ? "Cut what matters least"
            : "Make it longer with detail, examples and transitions that belong to what is already said, and never new facts, names or numbers"
        return "Edit the script so it runs between \(target.lowerBound) and \(target.upperBound) spoken words (it has \(sourceWords) now), keeping every key point. \(how)."
    }

    static func instruction(for tool: ScriptTool, context: RewriteContext) -> String {
        switch tool {
        case .fitToTime:
            let low = ReadTime.words(for: context.idealRange.lowerBound)
            let high = ReadTime.words(for: context.idealRange.upperBound)
            return "Edit the script so it runs between \(low) and \(high) spoken words, cutting or expanding while keeping every key point."
        case .moreEnergy:
            return "Rewrite with more energy: punchier verbs, shorter sentences, more excitement. Do not add facts."
        case .fixGrammar:
            return "Fix grammar, spelling and punctuation only. Do not change the wording otherwise and do not add or remove anything: answer with the whole text."
        case .translate:
            return "Translate the script into \((context.language ?? .spanish).englishName), keeping the tone. Translate the stage cues too."
        case .strongerCTA:
            return "Rewrite the closing below as a clearer, more direct call to action. Do not invent deadlines, discounts or facts that are not in the script."
        case .moreHuman:
            return "Make it sound more human and less scripted: plain words, no corporate phrasing."
        case .lessDefensive:
            return "Remove defensive language and excuses: delete lines like \"I didn't have a choice\" or \"it's not my fault\", and any \"but\" after " +
                "an apology. Keep the substance."
        case .shorterAndDirect:
            return "Make it about a third shorter and more direct. Remove filler and repetition, and keep every key point."
        case .inMyVoice:
            return "Rewrite the script so it sounds like the creator described in your instructions: their tone, words, style and catchphrases. " +
                "Put every sentence in their words, so that none stays as it is, and keep every point and about the same number of words as the script has."
        case .newHooks, .addDisclosure:
            return ""
        }
    }

    // MARK: - Cleaning

    /// Strips markdown, block labels and wrapping quotes the model sometimes adds, and normalizes
    /// paragraphs.
    static func clean(_ response: String) -> String {
        let lines: [String] = response
            .replacingOccurrences(of: "\r\n", with: "\n")
            .components(separatedBy: "\n")
            .compactMap { raw in
                var line = raw.trimmingCharacters(in: .whitespaces)
                if line.hasPrefix("#") || line == "---" || line.lowercased().hasPrefix("title:") { return nil }
                line = line.replacingOccurrences(of: "**", with: "").replacingOccurrences(of: "__", with: "")
                // A line that is only a block name, like "[Hook]" or "Hook:".
                let bare = line.trimmingCharacters(in: CharacterSet(charactersIn: "[]:").union(.whitespaces))
                if !bare.isEmpty, isBlockLabel(bare), line.count <= bare.count + 3 { return nil }
                if let colon = line.firstIndex(of: ":") {
                    let label = line[..<colon].trimmingCharacters(in: .whitespaces)
                    let rest = line[line.index(after: colon)...].trimmingCharacters(in: .whitespaces)
                    if !rest.isEmpty, isBlockLabel(label) { line = rest }
                }
                return line
            }
        var text = lines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
        if text.count > 2, let first = text.first, let last = text.last, "\"“".contains(first), "\"”".contains(last) {
            text = String(text.dropFirst().dropLast())
        }
        return ScriptTextNormalizer.normalize(text)
    }

    /// A title or a single line (hook, idea): one line, no markdown or wrapping quotes.
    static func cleanTitle(_ raw: String) -> String {
        var line = raw.components(separatedBy: .newlines).first { !$0.trimmingCharacters(in: .whitespaces).isEmpty } ?? ""
        line = line.replacingOccurrences(of: "**", with: "")
            .trimmingCharacters(in: CharacterSet(charactersIn: "#*-• ").union(.whitespaces))
        if line.count > 2, let first = line.first, let last = line.last, "\"“'".contains(first), "\"”'".contains(last) {
            line = String(line.dropFirst().dropLast())
        }
        return line.trimmingCharacters(in: .whitespaces)
    }

    /// Block names the model tends to echo as "Hook: …".
    private static func isBlockLabel(_ label: String) -> Bool {
        let known = Set(ScriptType.allCases.flatMap { $0.structure.blocks } + ScriptStructure.generic.blocks)
        return known.contains { $0.caseInsensitiveCompare(label) == .orderedSame }
    }
}
