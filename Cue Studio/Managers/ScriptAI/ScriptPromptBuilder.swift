//
//  ScriptPromptBuilder.swift
//  Cue Studio
//

import Foundation

/// Builds instructions and prompts for the on-device model, and cleans what comes back. Pure text,
/// so it can be tested without the model.
nonisolated enum ScriptPromptBuilder {
    static let cueHint = "Add short stage cues in square brackets where they help delivery, like [pause], [smile] or [look at camera]. Never put spoken words inside brackets."
    /// Cue writes no dashes in any language (the owner's rule). The hyphen is named as allowed: told only "no dashes", a small model starts
    /// splitting words. `DashRewriter` still rewrites any dash the model writes.
    static let punctuationRule = "Never use a dash (— or –) between words or sentences: use a full stop, comma, colon or parentheses. Hyphens inside words are fine."

    // MARK: - Generation

    static func instructions(for request: ScriptRequest, insistsOnLanguage: Bool = false) -> String {
        let structure = request.structure
        let voice = structure.isSerious ? nil : request.voice
        var lines = [
            "You write short-form video scripts that a creator reads from a teleprompter while filming themselves.",
            "Write in the first person, as the creator, in natural spoken language\(sentenceClause(for: voice)).",
            "Fill in a short title and the script blocks. Block text is only what the creator says: no headings, labels, markdown or quotes around it.",
            cueHint,
            punctuationRule,
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
            lines += voiceLines(voice, platform: request.platform, budget: request.voiceBudget)
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

    /// A script whose minimum is this many words or fewer (a video of a minute or so: TikTok, Reels, Shorts, Stories) is asked for as it is, with no
    /// sentence counts and no lengthening afterwards. Measured on an iPhone 15 Pro with "my daily routine with AI is not going so well" (three runs each,
    /// with and without a voice): asked as it was, the answer came in 6 to 35 s with 43 to 118 words, on the subject every time; asked for 1.5× with a
    /// count of sentences for every block it took 13 to 83 s for 132 to 262 words, padded with the same sentences again, and one run in six failed after
    /// 73 s. For a short video the wait and the subject matter more than 40 words; for a long one (YouTube) the model writes half of what it is
    /// asked and the extra ask is what gets the minutes (`PlatformLengthDeviceTests`).
    static let shortFormWords = 200

    /// The most a short video is asked to run to, whatever its creator's usual length: two minutes at 150 words a minute.
    static let shortFormCeiling = 300

    /// The words to ask the model for when the script needs `words`: `lengthAskFactor` times as many for a short script, fewer times as the script gets
    /// longer (a script of 1000 words or more is asked as it is: the model already writes the 1286 words of a YouTube video, and its answer is bounded).
    static func askedWords(_ words: Int) -> Int {
        // A short-form video is asked as it is (`shortFormWords`): see there.
        guard words > shortFormWords else { return words }
        let factor = words <= 250 ? lengthAskFactor : max(1.0, lengthAskFactor - (lengthAskFactor - 1.0) * Double(words - 250) / 750)
        return Int((Double(words) * factor).rounded())
    }

    /// The words the request asks the model for when the script must run `range` seconds: the floor as `askedWords` has it, and a ceiling that is not
    /// raised with it (a Short asked for 150 to 300 words wrote 310, two minutes of a script for a video of one), only kept above the floor.
    static func askedRange(for range: ClosedRange<TimeInterval>) -> (low: Int, high: Int) {
        let low = askedWords(ReadTime.words(for: range.lowerBound))
        var high = max(ReadTime.words(for: range.upperBound), Int((Double(low) * 1.25).rounded()))
        // A creator whose videos run one to three minutes asked 225 to 450 words for one line of idea (measured on an iPhone 15 Pro): the model
        // padded it with the same sentences and ran into its limit after 45 to 93 s. A short video is asked for no more than this.
        if low <= shortFormWords { high = min(high, shortFormCeiling) }
        return (low, max(low, high))
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
        let brief = structure.isSerious ? nil : request.brief
        if !structure.isSerious {
            lines.append(briefOpeningRule(brief) ?? hookRule(for: voice))
        }
        switch request.source {
        case .prompt:
            lines.append("The video: \(videoText(for: request))")
            if let angle = briefAngleRule(brief) { lines.append(angle) }
            // The idea is the subject. The voice only changes how it is said: a creator with other topics still gets a script about this one.
            if voice != nil { lines.append("Write about this idea and only this one: the creator's voice is how they sound, never what to talk about.") }
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
        var closing = voice.flatMap { closingRule(for: $0, platform: request.platform) }
        if voice != nil, case .prompt = request.source {
            closing = [closing, "Stay on the idea: \(videoText(for: request))"].compactMap { $0 }.joined(separator: " ")
        }
        if let closing { lines.append(closing) }
        return lines.joined(separator: "\n")
    }

    /// The shape of the script: the chosen format, else the one a free idea asks for (or the creator films most), else the generic one.
    static func formatGuide(for request: ScriptRequest) -> FormatGuide {
        if let type = request.type { return .guide(for: type) }
        guard case .prompt(let idea) = request.source else { return .generic }
        return .guide(for: FormatGuess.format(for: idea, usual: request.voice?.formats ?? []))
    }

    /// What the video is about, as the creator's text says it: for an idea from Find inspiration, without the lines of its angle and its opening line,
    /// which the request gives as rules of their own (`briefAngleRule`, `briefOpeningRule`). Measured on an iPhone 15 Pro: sent twice (as "Angle: … /
    /// Open with: “…”" and as rules) the brief came back as its opening block alone in 11 of 54 requests and the creator saw an error after ~50 s;
    /// sent once, 1 of 27, in 10.7 s on average against 19.9, as long and with the opening line kept every time.
    static func videoText(for request: ScriptRequest) -> String {
        guard case .prompt(let text) = request.source else { return "" }
        guard let brief = request.brief else { return text }
        let given = [brief.angle, brief.openingLine].filter { !$0.isEmpty }.map { IdeaBrief.tokens(in: $0) }
        guard !given.isEmpty else { return text }
        let kept = text.components(separatedBy: "\n").filter { line in
            let words = IdeaBrief.tokens(in: line)
            // A line that is mostly the angle or the opening line, in any order, with or without its label.
            return !given.contains { part in !part.isEmpty && Double(part.intersection(words).count) / Double(part.count) >= IdeaBrief.partShare }
        }
        let subject = kept.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
        return subject.isEmpty ? text : subject
    }

    /// An idea from Find inspiration brings its own first sentence (`IdeaBrief`): the script opens with it, or with it said the creator's way,
    /// instead of a hook of the model's that would leave the line the creator picked unsaid. Nil when the creator's text no longer has it.
    static func briefOpeningRule(_ brief: IdeaBrief?) -> String? {
        guard let line = brief?.openingLine, !line.isEmpty else { return nil }
        return "Open with this line, as it is or adapted only to the creator's way of speaking: “\(line)” It is the hook: write no other before it."
    }

    /// The angle of an idea from Find inspiration, when the creator's text still has it: what the script does with the subject.
    static func briefAngleRule(_ brief: IdeaBrief?) -> String? {
        guard let angle = brief?.angle, !angle.isEmpty else { return nil }
        return "Follow this angle all the way through: \(angle)"
    }

    /// Whether the first words must be about the subject, never a greeting or a filler: the device measurement (`ScriptQualityDeviceTests`,
    /// `TEST_RUNNER_CUE_QUALITY_SUBSTANCE=off`) compares it with the request as it was.
    nonisolated(unsafe) static var forbidsFillerOpening = true

    /// The hook, in the creator's own way of opening when they have one, never after a filler. Measured on an iPhone 15 Pro: told only "a hook", the
    /// model opened with one ("Olha só", "Hey", "¡Hola!") in 6 of 9 scripts with no voice; told this, in none.
    static func hookRule(for voice: CreatorVoice?) -> String {
        let filler = forbidsFillerOpening
            ? " The first words are already about the subject (a claim, a question or a number), never a greeting or a filler word such as “hey”, “hi”, "
                + "“so” or “look”."
            : ""
        guard let voice, !voice.openings.isEmpty else { return "Open with a hook that works in the first 3 seconds." + filler }
        return "Open with a hook that works in the first 3 seconds, in the creator's own way of opening." + filler
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

    /// A short script asked for "concrete points that name the real thing" instead of words was tried on an iPhone 15 Pro (run `substance`): it came
    /// out shorter (half its minimum, against 0.7), kept its opening's promise less (3 of 18 against 7 of 13) and invented ("filtro físico, como
    /// camuflagem"). Left out.
    static func lengthRule(minimumWords: Int, blocks: Int = 3, sentenceWords: Int = 12) -> String {
        guard asksSentencesPerBlock, minimumWords > shortFormWords else {
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
    static func voiceLines(_ voice: CreatorVoice, platform: Platform? = nil, budget: Int? = nil) -> [String] {
        VoiceBriefBuilder.brief(for: voice, budget: budget ?? VoiceBrief.budget, register: platform.map(PlatformRegister.init) ?? .casual).lines
    }

    /// "What Cue sends" (My Cue Voice): the voice as the model reads it, and what was cut to fit. Empty when nothing of the voice can be used yet.
    static func brief(for profile: CreatorProfile) -> VoiceBrief {
        guard profile.canWriteInMyVoice else { return .empty }
        return VoiceBriefBuilder.brief(for: profile.voice)
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
    static let honestyRule = "Never invent personal stories, clients, results, numbers or credentials for the creator: speak from general experience unless "
        + "the idea gives the details. Never say the creator did, tried, discovered or was saved by something unless the idea says so."

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
    static func themesInstructions(voice: CreatorVoice? = nil, voiceBudget: Int? = nil) -> String {
        var lines = ["You suggest video ideas for creators who film themselves talking to camera.", punctuationRule]
        if let voice { lines += voiceLines(voice, budget: voiceBudget) }
        return lines.joined(separator: "\n")
    }

    /// Ideas for what the creator makes videos about, all of it: the first flight's topics, the ones only the voice offers and the ones they typed, with
    /// what they cover inside each. Each of the six is ordered by its angle and its topic (`IdeaSlot`): told only what came before, the model copies it.
    /// `inspiration` is what the creator wrote or said lately (their Logbook, their latest scripts): the ideas are in its direction, never the same.
    /// - Parameter asBriefs: each idea as a whole brief (a title, the angle to take and an opening line, `IdeaBriefSuggestions`), as Find
    ///   inspiration and the card show them; false asks for titles alone (`ThemeSuggestions`), what the card had before, kept to measure the two
    ///   against each other on a device.
    static func themesPrompt(
        slots: [IdeaSlot], language: CueLanguage? = nil, inspiration: [String] = [], asBriefs: Bool = false
    ) -> String {
        func name(_ topic: IdeaTopic) -> String {
            topic.subtopics.isEmpty ? topic.name : "\(topic.name) (\(topic.subtopics.joined(separator: ", ")))"
        }
        var topics: [IdeaTopic] = []
        for slot in slots where !topics.contains(slot.topic) { topics.append(slot.topic) }
        var prompt = "Suggest \(slots.count) fresh talking-head video ideas for a creator whose topics are: \(topics.map(name).joined(separator: "; ")). "
        if asBriefs {
            prompt += "Each idea has a title of at most eight words, written the way a creator would post it: natural, specific, and promising something the "
                + "viewer gets, never a generic \"Top 5\" and never starting with the name of its angle as a label; an angle, one short sentence that tells the "
                + "creator what to do in the video, starting with a verb; and an opening line, the first sentence they say to camera, which leads straight into "
                + "the angle. Title, angle and opening line are one idea. In this order: "
        } else {
            prompt += "Each idea is a title of at most nine words, written the way a creator would post it: natural, specific, and promising something the viewer gets "
                + "(a number, a surprise, a mistake, a result), never a generic \"Top 5\" and never starting with the name of its angle as a label. In this order: "
        }
        prompt += slots.enumerated().map { index, slot in "\(index + 1). \(slot.angle.ask) about \(slot.topic.name)" }.joined(separator: "; ")
        prompt += asBriefs ? "." : ". Each idea names its topic exactly as written."
        if !inspiration.isEmpty {
            prompt += " The creator has been thinking about: \(inspiration.prefix(8).map { "“\($0.prefix(140))”" }.joined(separator: "; ")). "
                + "Let the ideas grow from what interests them, in new ways: never repeat these."
        }
        if asBriefs {
            // Said last, where the small model listens best: the line is put in the creator's mouth, so it must be something they can say honestly.
            prompt += " " + openingHonestyRule
        }
        if let language {
            prompt += " Write the ideas in \(language.englishName)."
        }
        return prompt
    }

    /// The opening line of an idea is said by the creator as their own: nothing in it may be something they haven't lived or can't stand behind, and
    /// nothing is presented as news or a trend (the ideas are not research).
    static let openingHonestyRule = "Opening lines must be true for anyone to say: no personal story, result, number or credential of the creator's, "
        + "and no statistic, study, news or trend."

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
            punctuationRule,
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

    /// Strips markdown, block labels and wrapping quotes the model sometimes adds, rewrites its dashes (`DashRewriter`) and normalizes
    /// paragraphs. Only for what the model wrote.
    /// - Parameters:
    ///   - language: the language of the answer, for the punctuation that replaces a dash; nil reads it from the text.
    ///   - preserving: the creator's words the model had to repeat, left as they are (`ScriptRequest.preservedPhrases`, `preserved(inRewriteOf:)`).
    static func clean(_ response: String, language: Locale.Language? = nil, preserving: [String] = []) -> String {
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
        return ScriptTextNormalizer.normalize(DashRewriter.rewrite(collapsingRepeatedCues(text), language: language, preserving: preserving))
    }

    /// A cue repeated three times in a row or more is the model stuck: "[pause]... [pause]... [pause]..." went on for hundreds, until its answer
    /// ran out (measured on an iPhone 15 Pro, 45 to 93 s for one idea). It stays once.
    static func collapsingRepeatedCues(_ text: String) -> String {
        text.replacing(/(\[[^\]\n]{1,40}\])(?:[\s.…]*\1){2,}[.…]*/) { String($0.output.1) }
    }

    /// A sentence said again word for word, after the first time, goes: a model that loops ("Esa es nuestra esencia. … Esa es nuestra misión. … Esa
    /// es nuestra esencia.") ran until its answer was cut off on the iPhone (1 script of 27 in a device run). Only for a script the model wrote: the
    /// creator may repeat a line on purpose. Sentences of fewer than three words ("Save this.") stay.
    static func collapsingRepeatedSentences(_ text: String) -> String {
        var seen = Set<String>()
        let paragraphs = text.components(separatedBy: "\n\n").compactMap { paragraph -> String? in
            let sentences = paragraph.matches(of: /[^.!?…。！？]+(?:[.!?…。！？]+|$)(?:\s*\[[^\]\n]{1,40}\])*/).map { String($0.output) }
            guard !sentences.isEmpty else { return paragraph }
            let kept = sentences.filter { sentence in
                let key = CueParser.stripCues(sentence).lowercased().filter { $0.isLetter || $0.isNumber || $0 == " " }
                    .split(separator: " ").joined(separator: " ")
                guard key.split(separator: " ").count >= 3 else { return true }
                return seen.insert(key).inserted
            }
            let joined = kept.map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }.joined(separator: " ")
            return joined.isEmpty ? nil : joined
        }
        return paragraphs.joined(separator: "\n\n")
    }

    /// A title or a single line (hook, idea): one line, no markdown, wrapping quotes or dashes (`clean`).
    static func cleanTitle(_ raw: String, language: Locale.Language? = nil, preserving: [String] = []) -> String {
        var line = raw.components(separatedBy: .newlines).first { !$0.trimmingCharacters(in: .whitespaces).isEmpty } ?? ""
        line = line.replacingOccurrences(of: "**", with: "")
            .trimmingCharacters(in: CharacterSet(charactersIn: "#*-• ").union(.whitespaces))
        if line.count > 2, let first = line.first, let last = line.last, "\"“'".contains(first), "\"”'".contains(last) {
            line = String(line.dropFirst().dropLast())
        }
        return DashRewriter.rewrite(line.trimmingCharacters(in: .whitespaces), language: language, preserving: preserving)
    }

    /// What a tool that edits the creator's script must leave as it is: the sentences of theirs that hold a dash (one the model kept word for
    /// word keeps it; one it rewrote comes back without) and their catchphrases. A translation is all the model's, so nothing.
    static func preserved(inRewriteOf source: String, tool: ScriptTool, voice: CreatorVoice?) -> [String] {
        guard tool != .translate else { return [] }
        return DashRewriter.sentencesWithDashes(in: source) + (voice?.phrases ?? [])
    }

    /// Block names the model tends to echo as "Hook: …".
    private static func isBlockLabel(_ label: String) -> Bool {
        let known = Set(ScriptType.allCases.flatMap { $0.structure.blocks } + ScriptStructure.generic.blocks)
        return known.contains { $0.caseInsensitiveCompare(label) == .orderedSame }
    }
}
