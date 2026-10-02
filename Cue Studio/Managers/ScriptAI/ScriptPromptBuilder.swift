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

    static func instructions(for request: ScriptRequest) -> String {
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
            lines.append(languageRule(language))
        }
        return lines.joined(separator: "\n")
    }

    /// Which language to write in, named in English so the rule reads the same whatever the
    /// interface language is.
    static func languageRule(_ language: CueLanguage) -> String {
        "Write the title and every block in \(language.englishName)."
    }

    static func prompt(for request: ScriptRequest) -> String {
        let structure = request.structure
        let low = ReadTime.words(for: request.targetRange.lowerBound)
        let high = ReadTime.words(for: request.targetRange.upperBound)
        var lines = [
            "Write a \(structure.label.lowercased()) script for \(request.platform.destinationName).",
            "Blocks, in this order: \(structure.blocks.joined(separator: " → ")).",
        ]
        if let tone = request.tone {
            lines.append("Tone: \(tone.label.lowercased()).")
        }
        lines.append("Length: between \(low) and \(high) spoken words in total.")
        if !structure.isSerious {
            lines.append("Open with a hook that works in the first 3 seconds.")
        }
        switch request.source {
        case .prompt(let text):
            lines.append("The video: \(text)")
        case .format(let type, let brief):
            let resolved = type.resolvedBrief(brief)
            lines.append("Brief:")
            lines += type.briefFields.map { "- \($0.label): \(resolved[$0.key] ?? $0.example)" }
        }
        return lines.joined(separator: "\n")
    }

    // MARK: - Voice

    /// Creator Voice as instructions: how they sound, the words they use, their style, catchphrases
    /// and niche.
    static func voiceLines(_ voice: CreatorVoice) -> [String] {
        var lines = ["Write in the creator's own voice."]
        if !voice.sounds.isEmpty {
            lines.append("They sound \(list(voice.sounds.map { $0.label.lowercased() })).")
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

    static func rewriteInstructions(voice: CreatorVoice? = nil) -> String {
        var lines = [
            "You edit teleprompter scripts for video creators.",
            "Keep the creator's voice and first person. Keep existing stage cues in square brackets unless the edit requires removing them.",
            "Return only the full edited script: no explanations, no headings, no markdown, no quotes around it.",
            "Separate paragraphs with a blank line.",
            "Keep the script in the language it is written in, unless you are asked to translate it.",
        ]
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
