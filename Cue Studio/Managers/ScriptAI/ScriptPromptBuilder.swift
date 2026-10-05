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
        var lines = [
            "You write short-form video scripts that a creator reads from a teleprompter while filming themselves.",
            "Write in the first person, as the creator, in natural spoken language with short sentences.",
            "Fill in a short title and the script blocks. Block text is only what the creator says: no headings, labels, markdown or quotes around it.",
            cueHint,
        ]
        if structure.isSerious {
            lines.append(seriousRule)
        }
        if request.isFreePrompt {
            lines.append(accuracyRule)
        }
        if let voice = request.voice, !structure.isSerious {
            lines += voiceLines(voice)
        }
        if let language = request.language {
            lines.append(languageRule(language, variant: request.languageVariant))
            if insistsOnLanguage || language != .english { lines.append(languageInsistence(language, variant: request.languageVariant)) }
        }
        return lines.joined(separator: "\n")
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

    static func prompt(for request: ScriptRequest) -> String {
        let structure = request.structure
        let low = ReadTime.words(for: request.targetRange.lowerBound)
        let high = ReadTime.words(for: request.targetRange.upperBound)
        var lines: [String] = []
        // On the iPhone 18 Pro Max the model wrote every script in English when the creator's voice (English instructions, an
        // English catchphrase) was on, whatever the instructions said: the language is also asked for in the request itself.
        if let language = request.language, language != .english || request.languageVariant != nil {
            lines.append("Language of the script: \(languageName(language, variant: request.languageVariant)). Write all of it in \(languageName(language, variant: request.languageVariant)).")
        }
        lines += [
            "Write a \(structure.label.lowercased()) script for \(request.platform.destinationName).",
            "Blocks, in this order: \(structure.blocks.joined(separator: " → ")).",
        ]
        if let tone = request.tone {
            lines.append("Tone: \(tone.label.lowercased()).")
        }
        lines.append("Length: between \(low) and \(high) spoken words in total.")
        // Measured on an iPhone: told only the range, the model wrote about a third of it (44 to 82 words for 150 to 225,
        // in every language). Naming the minimum and what a block holds is what makes it write the length.
        lines.append(lengthRule(minimumWords: low))
        if !structure.isSerious {
            lines.append("Open with a hook that works in the first 3 seconds.")
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
        return lines.joined(separator: "\n")
    }

    /// Every block gets full sentences, and the script doesn't stop before its minimum.
    static func lengthRule(minimumWords: Int) -> String {
        "Do not stop early: the script must be at least \(minimumWords) words, so write every block in full, with several complete sentences each."
    }

    // MARK: - Voice

    /// My Cue Voice as instructions: how they sound, the words they use, their style, catchphrases
    /// and niche.
    static func voiceLines(_ voice: CreatorVoice) -> [String] {
        var lines = ["Write in the creator's own voice."]
        if let role = voice.role {
            lines.append("They are a creator of this kind: \(role.label.lowercased()) (\(role.examples.lowercased())).")
            if role.speaksAsWe { lines.append("They speak as a team: say \"we\", not \"I\".") }
        }
        if !voice.sounds.isEmpty {
            lines.append("They sound \(list(voice.sounds.map(\.promptWord))).")
        }
        if let vocabulary = voice.vocabulary {
            lines.append(vocabularyRule(vocabulary))
        }
        if !voice.styles.isEmpty {
            lines.append("Their style: \(voice.styles.map { $0.label.lowercased() }.joined(separator: ", ")).")
        }
        if !voice.phrases.isEmpty {
            lines.append("They often say: \(voice.phrases.map { "\"\($0)\"" }.joined(separator: ", ")). Use one of these naturally, ideally in the opening.")
        }
        if !voice.niches.isEmpty {
            lines.append("Their niche: \(voice.niches.map(\.label).joined(separator: ", ")).")
        }
        if !voice.openings.isEmpty {
            lines.append("They like to open a video like this: \(quoted(voice.openings)).")
        }
        if !voice.endings.isEmpty {
            lines.append("They usually end a video like this: \(quoted(voice.endings)).")
        }
        if !voice.formats.isEmpty {
            lines.append("They film mostly: \(voice.formats.map { $0.structure.label.lowercased() }.joined(separator: ", ")).")
        }
        if let swearing = voice.swearing {
            lines.append(swearingRule(swearing))
        }
        lines += deliveryLines(voice)
        if !voice.customTags.isEmpty {
            lines.append("Also true of them: \(voice.customTags.joined(separator: ", ")).")
        }
        if !voice.examples.isEmpty {
            lines.append("Here is how they write. Match the voice, never copy the content:")
            lines += voice.examples.prefix(VoiceExample.limit).map { "- \"\($0.sentText)\"" }
        }
        return lines
    }

    /// "What Cue sends" (My Cue Voice, 9.3): the voice as the instructions the model reads, shown to the creator
    /// as it is sent. Empty when the creator's voice has nothing to say yet.
    static func voiceBrief(_ profile: CreatorProfile) -> String {
        guard profile.hasMinimumVoice else { return "" }
        return voiceLines(profile.voice).joined(separator: "\n")
    }

    /// What the question bank added: how they come across, who is watching, what to avoid and where they post.
    private static func deliveryLines(_ voice: CreatorVoice) -> [String] {
        var lines: [String] = []
        if let energy = voice.style.energy {
            lines.append("Their energy on camera is \(energy.label.lowercased()).")
        }
        if let sentences = voice.style.sentences {
            lines.append("They speak in \(sentences.label.lowercased()) sentences.")
        }
        if let words = voice.style.words {
            lines.append("Their words: \(words.label.lowercased()).")
        }
        if let level = voice.audienceLevel {
            lines.append("Their audience is \(level.label.lowercased()).")
        }
        if !voice.avoid.isEmpty {
            lines.append("Never write: \(voice.avoid.joined(separator: ", ")).")
        }
        var reach: [String] = []
        if !voice.reach.platforms.isEmpty { reach.append("they mostly post on \(voice.reach.platforms.map(\.label).joined(separator: ", "))") }
        if let length = voice.reach.length { reach.append("their videos are usually \(length.label)") }
        if let humor = voice.reach.humor { reach.append("humor in their videos: \(humor.label.lowercased())") }
        if !reach.isEmpty { lines.append(reach.joined(separator: "; ").capitalizedFirst + ".") }
        return lines
    }

    private static func quoted(_ items: [String]) -> String {
        items.map { "\"\($0)\"" }.joined(separator: ", ")
    }

    private static func swearingRule(_ swearing: Swearing) -> String {
        switch swearing {
        case .never: "Never swear."
        case .mild: "Mild swearing is fine now and then. Never write strong swearing or slurs."
        }
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

    private static func vocabularyRule(_ vocabulary: Vocabulary) -> String {
        switch vocabulary {
        case .simple: "Their audience is everyday people: use simple, everyday words."
        case .technical: "Their audience knows the field: technical terms are fine."
        case .genZ: "Their audience is young: use casual Gen Z slang where it fits, without overdoing it."
        case .professional: "Their audience is professionals: use polished, professional wording."
        }
    }

    private static func list(_ items: [String]) -> String {
        guard let last = items.last else { return "" }
        return items.count == 1 ? last : items.dropLast().joined(separator: ", ") + " and " + last
    }

    static let seriousRule = "This is a serious statement. Be sincere, specific and brief. No hooks, jokes, hype, emojis or calls to follow, like or subscribe. Never write \"but\" after taking responsibility."

    static let accuracyRule = "Be accurate. State only facts you are confident about; when unsure of a date, name or number, say it more generally instead of inventing it."

    // MARK: - Hooks and ideas

    static func hooksPrompt(for text: String, context: RewriteContext) -> String {
        """
        Write three new opening lines for this \(context.structure.label.lowercased()) script for \(context.platform.destinationName). \
        Each must grab attention in about three seconds and lead into the rest of the script. \
        Write them in the language the script is written in.

        Script:
        \(text)
        """
    }

    static func themesPrompt(for niches: [Niche], language: CueLanguage? = nil) -> String {
        let names = (niches.isEmpty ? [Niche.lifestyle] : niches).map(\.label).joined(separator: ", ")
        var prompt = "Suggest six fresh talking-head video ideas for a creator whose niche is: \(names). Mix the niches and the kinds of video. Use each niche name exactly as written."
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
            "Keep the creator's voice and first person. Keep existing stage cues in square brackets unless the edit requires removing them.",
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

    static func rewritePrompt(for text: String, tool: ScriptTool, context: RewriteContext) -> String {
        "\(instruction(for: tool, context: context))\n\nScript:\n\(text)"
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
            return "Fix grammar, spelling and punctuation only. Do not change the wording otherwise."
        case .translate:
            return "Translate the script into \((context.language ?? .spanish).englishName), keeping the tone. Translate the stage cues too."
        case .strongerCTA:
            return "Rewrite only the closing paragraph as a clearer, more direct call to action. Do not invent deadlines, discounts or facts that are not in the script."
        case .moreHuman:
            return "Make it sound more human and less scripted: plain words, no corporate phrasing."
        case .lessDefensive:
            return "Remove defensive language, excuses and any \"but\" after an apology, keeping the substance."
        case .shorterAndDirect:
            return "Make it shorter and more direct. Remove filler and repetition."
        case .inMyVoice:
            return "Rewrite the script so it sounds like the creator described in your instructions: their tone, words, style and catchphrases. Keep every point and the same length."
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

private nonisolated extension String {
    /// The first letter in capitals; the rest as it is.
    var capitalizedFirst: String { prefix(1).uppercased() + dropFirst() }
}
