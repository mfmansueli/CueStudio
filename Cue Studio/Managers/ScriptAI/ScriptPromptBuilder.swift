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
        let structure = request.type.structure
        var lines = [
            "You write short-form video scripts that a creator reads from a teleprompter while filming themselves.",
            "Write in the first person, as the creator, in natural spoken language with short sentences.",
            "Return only the script: no title, no headings, no labels, no markdown, no quotes around it.",
            "Separate paragraphs with a blank line. Each paragraph is one beat of the video.",
            cueHint,
        ]
        if structure.isSerious {
            lines.append("This is a serious statement. Be sincere, specific and brief. No hooks, jokes, hype, emojis or calls to follow, like or subscribe. Never write \"but\" after taking responsibility.")
        }
        if !request.niches.isEmpty {
            lines.append("The creator's niche: \(request.niches.map(\.label).joined(separator: ", ")).")
        }
        if !request.phrases.isEmpty && !structure.isSerious {
            lines.append("The creator often says: \(request.phrases.map { "\"\($0)\"" }.joined(separator: ", ")). Use one of these naturally, ideally in the opening.")
        }
        return lines.joined(separator: "\n")
    }

    static func prompt(for request: ScriptRequest) -> String {
        let structure = request.type.structure
        let brief = request.type.resolvedBrief(request.brief)
        let briefLines = request.type.briefFields.map { field in
            "- \(field.label): \(brief[field.key] ?? field.example)"
        }
        let low = ReadTime.words(for: request.idealRange.lowerBound)
        let high = ReadTime.words(for: request.idealRange.upperBound)
        return """
        Write a \(structure.label.lowercased()) script for \(request.platform.destinationName).
        Structure, one or more paragraphs per block, in this order: \(structure.blocks.joined(separator: " → ")).
        Tone: \(request.tone.label.lowercased()).
        Length: between \(low) and \(high) spoken words.
        \(structure.isSerious ? "" : "Open with a hook that works in the first 3 seconds.")
        Brief:
        \(briefLines.joined(separator: "\n"))
        """
    }

    // MARK: - Rewrites

    static func rewriteInstructions() -> String {
        [
            "You edit teleprompter scripts for video creators.",
            "Keep the creator's voice and first person. Keep existing stage cues in square brackets unless the edit requires removing them.",
            "Return only the full edited script: no explanations, no headings, no markdown, no quotes around it.",
            "Separate paragraphs with a blank line.",
        ].joined(separator: "\n")
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
            return "Translate the script into \(context.language ?? "Spanish"), keeping the tone. Translate the stage cues too."
        case .strongerCTA:
            return "Rewrite only the closing paragraph as a clearer, more direct call to action. Do not invent deadlines, discounts or facts that are not in the script."
        case .moreHuman:
            return "Make it sound more human and less scripted: plain words, no corporate phrasing."
        case .lessDefensive:
            return "Remove defensive language, excuses and any \"but\" after an apology, keeping the substance."
        case .shorterAndDirect:
            return "Make it shorter and more direct. Remove filler and repetition."
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

    /// Block names the model tends to echo as "Hook: …".
    private static func isBlockLabel(_ label: String) -> Bool {
        let known = Set(ScriptType.allCases.flatMap { $0.structure.blocks } + ScriptStructure.generic.blocks)
        return known.contains { $0.caseInsensitiveCompare(label) == .orderedSame }
    }
}
