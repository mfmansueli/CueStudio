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
            request.modelRoute == .privateCloud
                ? "You write video scripts that a creator reads from a teleprompter while filming themselves."
                : "You write short-form video scripts that a creator reads from a teleprompter while filming themselves.",
            request.modelRoute == .privateCloud
                ? "Write in natural spoken language\(sentenceClause(for: voice)). Follow the narrator and grammatical perspective requested in the current brief, including a team statement or second-person scene. Use the creator's usual perspective only when the request leaves it unspecified."
                : "Write in the first person, as the creator, in natural spoken language\(sentenceClause(for: voice)).",
            "Fill in a short title and the script blocks. Block text is only what the creator says: no headings, labels, markdown or quotes around it.",
            cueHint,
            punctuationRule,
        ]
        if structure.isSerious {
            lines.append(seriousRule)
            // A serious statement has no style, but the voice's rules still hold (the owner's B9; §11, A4).
            if let rules = request.rules { lines += VoiceBriefBuilder.restrictionLines(for: rules, register: PlatformRegister(request.platform)) }
        } else {
            // Where it is posted shapes the hook, the pace and the ending; a serious statement has none of those.
            lines.append(request.modelRoute == .privateCloud
                ? PCCScriptDirection.platformLine(for: request.platform, durationPolicy: request.durationPolicy)
                : PlatformGuide.line(for: request.platform, durationPolicy: request.durationPolicy, creatorEnds: voice?.decidesTheEnding ?? false))
            lines.append(request.modelRoute == .privateCloud ? PCCScriptDirection.draftLicense : honestyRule(for: request))
            if request.modelRoute == .privateCloud { lines.append(resultRule) }
        }
        lines.append(accuracyRule)
        if let voice {
            lines += voiceLines(voice, platform: request.platform, budget: request.voiceBudget, contextualPreferences: request.modelRoute == .privateCloud)
            lines.append(requestWinsRule)
        }
        if let language = request.language {
            lines.append(languageRule(language, variant: request.languageVariant))
            if insistsOnLanguage || language != .english { lines.append(languageInsistence(language, variant: request.languageVariant)) }
        }
        // Gender agreement and the form of address, in the languages that mark them (the owner's B8; §11.7).
        let theirs = request.voice ?? request.rules
        lines += AgreementGuide.lines(for: theirs?.agreement, speaksAs: theirs?.resolvedSpeaksAs ?? .i, language: AgreementGuide.code(of: request))
        lines += PCCScriptDirection.instructions(for: request)
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
        return "The script is in \(name), not in English: write it in \(name) even though these instructions are in English. "
            + "The creator's catchphrases stay as they are, as does any wording explicitly requested verbatim."
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
    /// - Parameter language: the script's, whose pace sets how many words the seconds hold (`ReadTime.pace(for:)`).
    static func askedRange(
        for range: ClosedRange<TimeInterval>, on route: AIModelRoute = .onDevice, language: CueLanguage? = nil
    ) -> (low: Int, high: Int) {
        let minimum = ReadTime.words(for: range.lowerBound, language: language)
        if route == .privateCloud {
            // Owner preference: provide material to edit near the chosen upper duration, at normal
            // reading pace. A small overrun is acceptable; this is not a platform upload limit.
            let upper = max(minimum, ReadTime.words(for: range.upperBound, language: language))
            return (max(minimum, Int((Double(upper) * 0.9).rounded(.up))), Int((Double(upper) * 1.05).rounded(.up)))
        }
        let low = askedWords(minimum)
        var high = max(ReadTime.words(for: range.upperBound, language: language), Int((Double(low) * 1.25).rounded()))
        // A creator whose videos run one to three minutes asked 225 to 450 words for one line of idea (measured on an iPhone 15 Pro): the model
        // padded it with the same sentences and ran into its limit after 45 to 93 s. A short video is asked for no more than this.
        if low <= shortFormWords { high = min(high, shortFormCeiling) }
        return (low, max(low, high))
    }

    static func prompt(for request: ScriptRequest) -> String {
        let structure = request.structure
        let (low, high) = askedRange(for: request.targetRange, on: request.modelRoute ?? .onDevice, language: request.language)
        var lines: [String] = []
        // On the iPhone 18 Pro Max the model wrote every script in English when the creator's voice (English instructions, an
        // English catchphrase) was on, whatever the instructions said: the language is also asked for in the request itself.
        if let language = request.language, language != .english || request.languageVariant != nil {
            lines.append("Language of the script: \(languageName(language, variant: request.languageVariant)). Write all of it in \(languageName(language, variant: request.languageVariant)).")
        }
        // The shape: the format the creator chose, or the one the idea asks for (only the AI is told), in English with what each block is for.
        let guide = formatGuide(for: request)
        let automatic = PCCScriptDirection.usesAutomaticFormat(request)
        if automatic {
            lines.append("Write a script for \(request.platform.promptName).")
            lines += PCCScriptDirection.automaticFormatLines(for: request)
        } else {
            lines += [
                "Write a \(guide.name) script for \(request.platform.promptName).",
                "Blocks, in this order: \(guide.order).",
                "What each block does: \(guide.purpose)",
            ]
        }
        if request.durationPolicy == .targeted {
            lines.append("Length: between \(low) and \(high) spoken words in total.")
            lines.append(lengthRule(
                minimumWords: low, blocks: guide.blocks.count, sentenceWords: sentenceWords(for: request.voice), on: request.modelRoute ?? .onDevice
            ))
        } else {
            lines.append("Platform duration is informational, not a writing target. Develop the current request fully and naturally, then stop when it is complete. Do not pad or cut useful content to fit a platform duration. Honor any length explicitly requested by the creator.")
        }
        let voice = structure.isSerious ? nil : request.voice
        let brief = structure.isSerious ? nil : request.brief
        if !structure.isSerious {
            if let opening = briefOpeningRule(brief) {
                lines.append(opening)
            } else if !automatic {
                lines.append(hookRule(for: voice))
            }
        }
        lines += sourceLines(for: request, voice: voice, brief: brief)
        if let brand = request.brand {
            lines += brandLines(brand)
        }
        // Said again at the very end, where a small model listens best.
        var closing = voice.flatMap {
            closingRule(for: $0, platform: request.platform, contextualPreferences: request.modelRoute == .privateCloud)
        }
        if voice != nil, case .prompt = request.source {
            let focus = request.modelRoute == .privateCloud
                ? "Keep the current request's subject and explicit requirements; use usual voice preferences only where they fit."
                : "Stay on the idea: \(videoText(for: request))"
            closing = [closing, focus].compactMap { $0 }.joined(separator: " ")
        }
        if let closing { lines.append(closing) }
        lines += request.requiredPhrases.map { "Mandatory verbatim wording, unchanged in a spoken block: “\($0)”" }
        if request.modelRoute == .privateCloud { lines.append(PCCScriptDirection.finalCheck) }
        return lines.joined(separator: "\n")
    }

    private static func sourceLines(for request: ScriptRequest, voice: CreatorVoice?, brief: IdeaBrief?) -> [String] {
        var lines: [String] = []
        switch request.source {
        case .prompt:
            lines.append("The video: \(videoText(for: request))")
            if let topic = briefTopicRule(brief) { lines.append(topic) }
            if let angle = briefAngleRule(brief) { lines.append(angle) }
            // The idea is the subject. The voice only changes how it is said: a creator with other topics still gets a script about this one.
            if voice != nil {
                lines.append(request.modelRoute == .privateCloud
                    ? "Stay on the current request. Profile information guides the writing style; do not quote or explain the profile instructions in the script."
                    : "Write about this idea and only this one: the creator's voice is how they sound, never what to talk about.")
            }
        }
        return lines
    }

    /// The shape of the script: the chosen format, else the one a free idea asks for (or the creator films most), else the generic one.
    /// Its closing block ends as the creator does (`FormatGuide.ending(for:)`); a serious statement has no voice, so its shape stays.
    static func formatGuide(for request: ScriptRequest) -> FormatGuide {
        let voice = request.structure.isSerious ? nil : request.voice
        if let type = request.type { return FormatGuide.guide(for: type).ending(for: voice) }
        if request.formatChoice == .talkingHead { return FormatGuide.talkingHead.ending(for: voice) }
        guard case .prompt(let idea) = request.source else { return FormatGuide.generic.ending(for: voice) }
        return FormatGuide.guide(for: FormatGuess.format(for: idea, usual: request.voice?.formats ?? [])).ending(for: voice)
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

    /// The creator's topic an idea from Find inspiration (or the card) was written for: the script stays inside it, whatever the headline leaves
    /// out. Nil when the brief came without one (kept by an older version).
    static func briefTopicRule(_ brief: IdeaBrief?) -> String? {
        guard let topic = brief?.topic?.trimmingCharacters(in: .whitespacesAndNewlines), !topic.isEmpty else { return nil }
        return "The idea was suggested for the creator's topic “\(topic)”: keep the video inside that topic."
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
    static func closingRule(for voice: CreatorVoice, platform: Platform? = nil, contextualPreferences: Bool = false) -> String? {
        let rules = VoiceBriefBuilder.closingRules(
            for: voice, register: platform.map(PlatformRegister.init) ?? .casual, contextualPreferences: contextualPreferences
        )
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
    static func lengthRule(minimumWords: Int, blocks: Int = 3, sentenceWords: Int = 12, on route: AIModelRoute = .onDevice) -> String {
        if route == .privateCloud {
            let development = Int((Double(minimumWords) * 0.85).rounded(.up))
            return "Budget the spoken script before writing: at least \(development) words belong to the actual development, not the opening or sign-off. "
                + "Distribute that development across the requested steps or sections; explain each with several connected sentences, a reason and a useful check or example. "
                + "Keep the requested number of points. A one-sentence tip is not a developed section. "
                + "Aim near the upper end of the chosen duration at a natural reading pace, with at least \(minimumWords) spoken words. "
                + "Give the creator substantial material to edit: develop the relevant explanation, practical details and tradeoffs. "
                + "A small overrun is acceptable. Never stretch the duration with repetition, invented facts or generic motivational filler. "
                + "If an explicit word or time limit appears in the current request, honor that limit instead."
        }
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
    static func voiceLines(
        _ voice: CreatorVoice, platform: Platform? = nil, budget: Int? = nil, contextualPreferences: Bool = false
    ) -> [String] {
        VoiceBriefBuilder.brief(
            for: voice, budget: budget ?? VoiceBrief.budget, register: platform.map(PlatformRegister.init) ?? .casual,
            contextualPreferences: contextualPreferences
        ).lines
    }

    /// "What Cue sends" (My Cue Voice): the voice as a script's request reads it (no usual length: `AIRequestPolicy.prepare`), and what was cut to
    /// fit. Empty when nothing of the voice can be used yet.
    /// - Parameter phrases: the catchphrases the next script is offered (`CreatorProfileService.nextCatchphrases`); nil keeps them all.
    static func brief(for profile: CreatorProfile, phrases: [String]? = nil) -> VoiceBrief {
        guard profile.canWriteInMyVoice else { return .empty }
        var voice = profile.voice
        voice.reach.length = nil
        if let phrases { voice.phrases = phrases }
        return VoiceBriefBuilder.brief(for: voice)
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

    /// A story the creator tells in the first person ("O dia em que eu desisti da dieta", or the storytime format): its scene may be imagined
    /// with the numbers of a routine, never with a result (the owner's B12, 02/11/2026; §11, A11b). Measured on an iPhone 15 Pro (01/11/2026):
    /// "Eu perdi 2 quilos em 7 dias" for that idea.
    static let storyHonestyRule = "This is the creator's own story: imagine the everyday details of the scene, and routine numbers (how many times "
        + "a week, minutes, days) may describe it. Never invent a result (weight, money, percentages, gains, cures), a statistic, a price, a client "
        + "or a credential that the idea doesn't give."

    /// What Private Cloud Compute's license to imagine never covers (B12).
    static let resultRule = "Never put a result (weight, money, percentages, gains, cures), a statistic or a price that the request doesn't give "
        + "in the creator's mouth; routine numbers may describe an imagined scene."

    /// The owner's order (B1, 02/11/2026; §11, A8): this video's request, then the creator's rules, then their habits, then the platform. Said once,
    /// outside the voice's brief, whose budget was measured on an iPhone (`VoiceBrief.budget`).
    static let requestWinsRule = "If this video's request asks in so many words for something the creator's rules or habits leave out "
        + "(an ending, a word, a call to action), the request wins."

    static func honestyRule(for request: ScriptRequest) -> String {
        isFirstPersonStory(request) ? storyHonestyRule : honestyRule
    }

    /// The storytime format (chosen, or the one `formatGuide(for:)` guesses), or a talking video that says "I" in its own language: a list or a
    /// tutorial in the first person ("Minha rotina de manhã") is advice, not a story.
    static func isFirstPersonStory(_ request: ScriptRequest) -> Bool {
        let format = request.type ?? FormatGuess.format(for: request.creatorText, usual: request.voice?.formats ?? [])
        if format == .story { return true }
        guard format == nil else { return false }
        let code = request.language?.locale.language.languageCode?.identifier ?? "en"
        guard let lexicon = WritingLexicon.lexicon(for: code) else { return false }
        let tokens = request.creatorText.lowercased().split { !($0.isLetter || $0 == "'" || $0 == "’") }.map(String.init)
        return tokens.contains(where: lexicon.singular.contains)
    }

    /// Every edit, with or without a voice (the owner's B12, 02/11/2026): a number can describe a scene, never a result the creator didn't give.
    static let editHonestyRule = "Never add a personal result, statistic, price, client or credential that the script doesn't already state."

    static let accuracyRule = "Be accurate. State only facts you are confident about; when unsure of a date, name or number, say it more generally instead of inventing it."

    // MARK: - Hooks and ideas

    /// "3 new hooks": three lines that each take the place of the script's hook (`ScriptHook`, its opening sentence, not its whole first paragraph),
    /// named so the model writes replacements for it, short enough to be said in the hook's few seconds (`ScriptBlocks.hookTarget`, the tip's
    /// measure), in the script's language.
    static func hooksPrompt(for text: String, context: RewriteContext) -> String {
        let hook = ScriptHook.text(of: text)
        let words = Int(ScriptBlocks.hookTarget * ReadTime.wordsPerMinute(speed: ReadTime.naturalSpeed, language: context.paceLanguage) / 60)
        let language = context.sourceLanguage.flatMap(CueLanguage.matching(language:)).map { languageName($0) }
        let replaces = hook.isEmpty ? "" : "Each takes the place of the opening line the script has now (\"\(CueParser.stripCues(hook))\") and leads "
            + "into what comes after it. "
        let written = language.map { $0 == "English" ? "Write them in English." : "Write them in \($0), not in English." }
            ?? "Write them in the language the script is written in."
        return """
        Write five new opening lines for this script, which will be posted on \(context.platform.promptName). \
        \(replaces)Each must grab attention and be said in about three seconds: at most \(words) words, fewer is better. \
        The five are different from each other and from the opening line now, and each opens in its own way: no greeting or catchphrase \
        at the start of more than one. \(written)\(context.brand.map { "\n" + adHookRule($0) } ?? "")

        Script:
        \(text)
        """
    }

    /// What the model is told before it suggests ideas: who it works for, and the creator's voice when there is one (their topics, who is
    /// watching and why) so the ideas are theirs and not any creator's.
    /// Told the same in Apple's own words for the language (`localePhrase`, `nativeAnswerRule`), the iPhone's model wrote no better ideas outside
    /// English (`IdeaLanguageDeviceTests`, 03/11/2026): what made them particular was a concrete subject for each (`IdeaSlot.subject`).
    static func themesInstructions(voice: CreatorVoice? = nil, voiceBudget: Int? = nil) -> String {
        var lines = ["You suggest video ideas for creators who film themselves talking to camera.", punctuationRule]
        if let voice { lines += voiceLines(voice, budget: voiceBudget) }
        return lines.joined(separator: "\n")
    }

    /// Apple's exact phrase for the person's locale, first in the instructions: it comes from the model's training and lowers hallucinations outside
    /// U.S. English ("Supporting languages and locales with Foundation Models"). None for U.S. English.
    static func localePhrase(_ language: CueLanguage) -> String? {
        language == .english ? nil : "The person's locale is \(language.locale.identifier(.icu))."
    }

    /// The language to answer in, as Apple words it, and how: as its speakers write it, never translated from English.
    static func nativeAnswerRule(_ language: CueLanguage) -> String {
        let name = language.englishName
        let culture = country(of: language).map { " and other cultural contexts of \($0)" } ?? ""
        return "You MUST respond in \(name) and be mindful of \(name) spelling, vocabulary, entities\(culture). Write everything the way a native "
            + "speaker would, never as a word-for-word translation of English."
    }

    /// The country of the language's region, named in English.
    static func country(of language: CueLanguage) -> String? {
        language.locale.region.flatMap { Locale(identifier: "en").localizedString(forRegionCode: $0.identifier) }
    }

    /// Ideas for what the creator makes videos about, all of it: the first flight's topics, the ones only the voice offers and the ones they typed, with
    /// what they cover inside each. Each of the six is ordered by its angle and its topic (`IdeaSlot`): told only what came before, the model copies it.
    /// `inspiration` is what the creator wrote or said lately (their Logbook, their latest scripts): the ideas are in its direction, never the same.
    /// - Parameter asBriefs: each idea as a whole brief (a title, the angle to take and an opening line, `IdeaBriefSuggestions`), as Find
    ///   inspiration and the card show them; false asks for titles alone (`ThemeSuggestions`), what the card had before, kept to measure the two
    ///   against each other on a device.
    /// Each idea is kept to its own topic (the owner, 03/11/2026: a creator of AI, daily routines and cooking got ideas that blended them): the
    /// topics are not listed together, each slot names its own, and what the creator wrote lately feeds only an idea of its topic; two slots of
    /// six join two topics (`IdeaSlot.bridging`).
    /// - Parameter creator: who they are and what their videos are for (`IdeaCreator`): a lawyer who wants clients gets ideas that bring them.
    static func themesPrompt(
        slots: [IdeaSlot], language: CueLanguage? = nil, inspiration: [String] = [], asBriefs: Bool = false, creator: IdeaCreator? = nil
    ) -> String {
        var prompt = "Suggest \(slots.count) fresh talking-head video ideas for a creator, each about its own topic unless joined with another. "
        if let line = creator?.promptLine { prompt += line + " " }
        if asBriefs {
            prompt += "Each idea has a title of at most eight words, written the way a creator would post it: natural, specific, and promising something the "
                + "viewer gets, never a generic \"Top 5\" and never starting with the name of its angle as a label; an angle, one short sentence that tells the "
                + "creator what to do in the video, starting with a verb; and an opening line, the first sentence they say to camera, which leads straight into "
                + "the angle. Title, angle and opening line are one idea, and the title or angle names the exact subject (never just \"products\"). "
                + "In this order: "
        } else {
            prompt += "Each idea is a title of at most nine words, written the way a creator would post it: natural, specific, and promising something the viewer gets "
                + "(a number, a surprise, a mistake, a result), never a generic \"Top 5\" and never starting with the name of its angle as a label. In this order: "
        }
        prompt += slots.enumerated().map { index, slot in
            let subject = slot.subject.map { ", around this subject: \($0)" } ?? ""
            // Inside the subtopic the slot is about (`IdeaSlot.focusing`): with up to ten a theme, naming them all cost the window more than the
            // ideas used, and the model drifted to the first ones.
            let topic = slot.subtopic.map { "\(slot.topic.name) (\($0))" } ?? slot.topic.name
            let bridge = slot.bridge.map { ", joined with \($0.name): one idea where the two meet" } ?? ""
            return "\(index + 1). \(slot.angle.ask) about \(topic)\(subject)\(bridge)\(slot.tie?.promptClause ?? "")"
        }.joined(separator: "; ")
        prompt += asBriefs ? "." : ". Each idea names its topic exactly as written."
        if !inspiration.isEmpty {
            prompt += " The creator has been thinking about: \(inspiration.prefix(8).map { "“\($0.prefix(140))”" }.joined(separator: "; ")). "
            prompt += "An idea may grow from one on its own topic, in a new way: never repeat or carry them across topics."
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
    /// - Parameter brand: the brief of the sponsored ad being edited (`RewriteContext.brand`): what every tool keeps (`brandKeepLines`).
    /// - Parameter rules: the voice's rules (`RewriteContext.rules`) for a tool that doesn't take the whole voice: what they avoid and who is
    ///   talking hold through every edit (the owner's B9; §11, A2).
    /// - Parameter translatingTo: the language a translation goes into, in English: what they avoid is avoided in it too.
    static func rewriteInstructions(
        voice: CreatorVoice? = nil, rules: CreatorVoice? = nil, register: PlatformRegister = .casual, language: Locale.Language? = nil,
        translatingTo: String? = nil, brand: BrandBrief? = nil
    ) -> String {
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
        if var voice {
            // A tool keeps the script's length or is told one ("Fit to time", "Shorter"): the usual one would be a second (§11, A15).
            voice.reach.length = nil
            // A tool keeps the script's points; "Adjust" › Too many ideas says so in its own instruction (`inMyVoiceLength`).
            voice.style.oneIdea = false
            lines += voiceLines(voice)
        } else if let rules {
            lines += VoiceBriefBuilder.restrictionLines(for: rules, register: register, translatingTo: translatingTo)
        }
        if let theirs = voice ?? rules {
            lines += AgreementGuide.lines(
                for: theirs.agreement, speaksAs: theirs.resolvedSpeaksAs, language: AgreementGuide.code(of: language), chosenOnly: true
            )
        }
        lines.append(editHonestyRule)
        if let brand { lines += brandKeepLines(brand) }
        return lines.joined(separator: "\n")
    }

    /// What a tool that edits a sponsored ad (rewrites, hooks, a version for another platform, a translation) is told, so the brand's brief
    /// survives the edit as it did the draft (`brandLines`): the disclosure, what it must and must never say, the link and the code.
    static func brandKeepLines(_ brand: BrandBrief) -> [String] {
        var lines = [
            "This script is a sponsored ad for \(brand.name) (\(brand.product)). Keep the paid partnership disclosure (#ad). Never add claims, "
                + "results, prices, discounts or guarantees the script doesn't already make.",
        ]
        if !brand.mustSay.isEmpty { lines.append("Keep what the brand asked the ad to say, with the same meaning: \(brand.mustSay)") }
        if !brand.neverSay.isEmpty { lines.append("Never say or mention: \(brand.neverSay)") }
        let exact = [brand.link, brand.code].filter { !$0.isEmpty }
        if !exact.isEmpty { lines.append("Keep exactly as written: \(exact.joined(separator: ", ")).") }
        return lines
    }

    /// An ad's new opening line promises nothing the brand didn't approve (`BrandBrief`).
    static func adHookRule(_ brand: BrandBrief) -> String {
        "This script is a sponsored ad for \(brand.name) (\(brand.product)): no opening line claims a result, price, discount or guarantee the script "
            + "doesn't make" + (brand.neverSay.isEmpty ? "." : ", and none says or mentions: \(brand.neverSay)")
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
        /// Words to write as new sentences that go into the script, the answer being only those ("Fit to time" short of its range, `FitTopUp`).
        var addition: Int?
    }

    /// - Parameter route: the model that answers; "Shorter" is asked with a count of words only on Private Cloud Compute (`shorterInstruction`).
    static func rewritePrompt(
        for text: String, tool: ScriptTool, context: RewriteContext, part: RewritePart = RewritePart(), on route: AIModelRoute = .onDevice
    ) -> String {
        if let addition = part.addition { return additionPrompt(words: addition, script: text) }
        var lines: [String] = []
        if tool == .fitToTime, let target = part.target {
            lines.append(fitInstruction(for: target, sourceWords: ReadTime.wordCount(in: text)))
        } else if tool == .shorterAndDirect, route == .privateCloud {
            lines.append(shorterInstruction(sourceWords: ReadTime.wordCount(in: text)))
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

    /// `answer` without the lines of the prompt it repeated: on the iPhone, a translation came back opening with "This is part 1 of 3 of a longer
    /// script. Edit only this part…" (ScriptToolsQualityDeviceTests, 01/11/2026). A line the script itself has stays.
    static func withoutEchoedInstructions(_ answer: String, prompt: String, source: String) -> String {
        func key(_ line: Substring) -> String {
            line.lowercased().split(whereSeparator: \.isWhitespace).joined(separator: " ")
        }
        let script = Set(source.split(separator: "\n").map(key))
        let asked = Set(prompt.split(separator: "\n").map(key).filter { $0.count > 20 && !script.contains($0) }).union(["script:"])
        let lines = answer.split(separator: "\n", omittingEmptySubsequences: false)
        let kept = lines.filter { !asked.contains(key($0)) }
        guard kept.count < lines.count else { return answer }
        return kept.joined(separator: "\n").replacing(/\n{3,}/, with: "\n\n").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// What to add to a script that "Fit to time" left short (`FitTopUp`): new sentences only, which go in before its closing line.
    static func additionPrompt(words: Int, script: String) -> String {
        "Write what to add to this script so it runs longer: about \(words) more spoken words, as one more point, an example or a moment from the "
            + "speaker's own day that belongs to what the script already says, to go just before its closing line. Same language and voice. No new "
            + "facts, names, numbers or studies, and no stage cues in brackets. Answer with only the new sentences, not the script.\n\nScript:\n\(script)"
    }

    /// "Shorter" with the words it has and the words to answer with, for Private Cloud Compute. Measured on the iPhone (ScriptToolsQualityDeviceTests,
    /// 01/11/2026), told only "about a third shorter", it gave a passage of 16 to 44 words back with a word or two less (or none) six times in ten,
    /// and with the count none (10 of 10, whole scripts 10 of 10). The device model did worse with it (whole scripts 9 of 10 → 5 of 10, iOS 27.2) and
    /// keeps the words alone (`instruction(for:)`).
    static func shorterInstruction(sourceWords: Int) -> String {
        "Make it about a third shorter and more direct: it has \(sourceWords) words now, answer with about \(max(1, Int(Double(sourceWords) * 0.65))). "
            + "Remove filler and repetition, and keep every key point."
    }

    /// "Fit to time" for a part: the words it is to have, and how to get there. Measured on the iPhone (ScriptToolsQualityDeviceTests, 01/11/2026),
    /// asked to take a script of 50 to 66 words to 188–263, Private Cloud Compute wrote 129 to 183: a script that must grow to twice its length or
    /// more is told how many times, and to give every point more sentences, which a model follows better than a count of words.
    static func fitInstruction(for target: ClosedRange<Int>, sourceWords: Int) -> String {
        let growth = Double(target.lowerBound + target.upperBound) / 2 / Double(max(1, sourceWords))
        let how = if target.upperBound * 2 < sourceWords {
            "That is less than half of it: keep the opening line, the one or two points that matter most and the closing call to action, each in a "
                + "sentence or two, and leave the rest out"
        } else if sourceWords > target.upperBound {
            "Cut what matters least"
        } else if growth >= 1.8 {
            "That is about \(Int(growth.rounded())) times as long as it is now: give every point two or three more sentences of detail, an example "
                + "or what it looks like in practice, all of it belonging to what is already said, and never new facts, names or numbers"
        } else {
            "Make it longer with detail, examples and transitions that belong to what is already said, and never new facts, names or numbers"
        }
        return "Edit the script so it runs between \(target.lowerBound) and \(target.upperBound) spoken words (it has \(sourceWords) now), keeping every key point. \(how)."
    }

    /// How much of the script "In my voice" keeps: all of it, or what "Adjust" › Too long said was too long (`RewriteContext.shortening`). A third
    /// fewer words stays inside what the tool may answer (`RewriteOutcome.allowedWords`).
    static func inMyVoiceLength(_ shortening: TooLongCause?) -> String {
        switch shortening {
        case .video?:
            "keep every key point in about a third fewer words than the script has: cut filler and repetition."
        case .ideas?:
            "keep its one main idea and cut the side points, so it comes out about a third shorter."
        case .sentences?:
            "keep every point and about the same number of words as the script has, in shorter sentences."
        case nil:
            "keep every point and about the same number of words as the script has."
        }
    }

    static func instruction(for tool: ScriptTool, context: RewriteContext) -> String {
        switch tool {
        case .fitToTime:
            let low = ReadTime.words(for: context.idealRange.lowerBound, language: context.paceLanguage)
            let high = ReadTime.words(for: context.idealRange.upperBound, language: context.paceLanguage)
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
            // The selection's "Rewrite" is this tool on a few sentences. Measured on the iPhone (ScriptToolsQualityDeviceTests, 01/11/2026), told to
            // sound more human, both models gave a passage that already sounded spoken back as it was (3 of 10): a passage is said another way.
            if context.isPassage {
                return "Say it another way, as you would say it out loud: reword every sentence in plain, spoken words, keeping what it means and every point."
            }
            return "Make it sound more human and less scripted: plain words, no corporate phrasing."
        case .lessDefensive:
            return "Remove defensive language and excuses: delete lines like \"I didn't have a choice\" or \"it's not my fault\", and any \"but\" after " +
                "an apology. Keep the substance."
        case .shorterAndDirect:
            return "Make it about a third shorter and more direct. Remove filler and repetition, and keep every key point."
        case .inMyVoice:
            return "Rewrite the script so it sounds like the creator described in your instructions: their tone, words, style and catchphrases. " +
                "Put every sentence in their words, so that none stays as it is, and \(inMyVoiceLength(context.shortening)) " +
                "Use each catchphrase once at most, a greeting only at the very start, and keep the script's own point of view."
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
    ///   - source: the creator's text a rewrite started from. A cue it repeats three times in a row ("[pause] [pause] [pause]") is theirs, on
    ///     purpose, and the answer keeps it (collapsed, the rewrite read as cues lost and the part was left as written).
    static func clean(_ response: String, language: Locale.Language? = nil, preserving: [String] = [], source: String? = nil) -> String {
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
        let keepsRepeats = source.map { collapsingRepeatedCues($0) != $0 } ?? false
        let cues = keepsRepeats ? text : collapsingRepeatedCues(text)
        return ScriptTextNormalizer.normalize(DashRewriter.rewrite(cues, language: language, preserving: preserving))
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
    static func preserved(inRewriteOf source: String, tool: ScriptTool, voice: CreatorVoice?, brand: BrandBrief? = nil) -> [String] {
        let exact = [brand?.link ?? "", brand?.code ?? ""].filter { !$0.isEmpty }
        guard tool != .translate else { return exact }
        return DashRewriter.sentencesWithDashes(in: source) + (voice?.phrases ?? []) + exact
    }

    /// Block names the model tends to echo as "Hook: …".
    private static func isBlockLabel(_ label: String) -> Bool {
        let known = Set(ScriptType.allCases.flatMap { $0.structure.blocks } + ScriptStructure.generic.blocks + [FormatGuide.closeBlock])
        return known.contains { $0.caseInsensitiveCompare(label) == .orderedSame }
    }
}
