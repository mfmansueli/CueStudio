//
//  ScriptExpansionPrompt.swift
//  Cue Studio
//

import Foundation

/// What the model is told to lengthen or shorten one block of a script: its job, the language, the creator's voice when they have one, and the block
/// with the size it must reach. In English, whatever the script's language, with the language named in the request.
nonisolated enum ScriptExpansionPrompt {
    static func instructions(for request: ScriptRequest, direction: ScriptExpansion.Direction = .longer) -> String {
        var lines = [
            direction == .longer
                ? "You make one block of a creator's spoken video script longer, so that it can be read out on camera."
                : "You make one block of a creator's spoken video script shorter, so that it can be read out on camera in the time there is.",
            direction == .longer
                ? "Keep the creator's voice, the first person and every idea already there. "
                    + "Add concrete detail, a short example or the reason why, in complete sentences."
                : "Keep the creator's voice, the first person and the one idea of the block. "
                    + "Cut what repeats and what is least needed, and keep complete sentences.",
            "Never invent personal stories, clients, results, numbers or credentials. Say facts only when you are sure of them.",
            "Keep the stage cues in square brackets, and put no spoken words inside brackets.",
            "Answer only with the new text of the block: no label, no heading, no quotes, no markdown.",
        ]
        if let language = request.language, language != .english || request.languageVariant != nil {
            lines.append(ScriptPromptBuilder.languageRule(language, variant: request.languageVariant))
        }
        // The creator's voice in its short form: who is talking and what is never written, and how long their sentences run.
        if let voice = request.voice {
            if let closing = ScriptPromptBuilder.closingRule(for: voice, platform: request.platform) { lines.append(closing) }
            lines.append("Their sentences are about \(ScriptPromptBuilder.sentenceWords(for: voice)) words long.")
        }
        return lines.joined(separator: "\n")
    }

    /// The request for one block: the video, what the block is for, its words now and the words it must reach.
    static func prompt(for step: ScriptExpansion.Step, of blocks: [String], request: ScriptRequest, purpose: String?) -> String {
        var lines: [String] = []
        if case .prompt(let idea) = request.source { lines.append("The video: \(idea)") }
        lines.append("The script has \(blocks.count) blocks. This is block \(step.index + 1)" + (purpose.map { ": \($0)" } ?? "."))
        if step.index > 0 { lines.append("The block before it ends: \(tail(of: blocks[step.index - 1]))") }
        // The model counts sentences, not words: asked for "about 45 words" it wrote a hundred, asked for four sentences it wrote four.
        let spoken = CueParser.stripCues(blocks[step.index])
        let now = max(1, WritingText.sentences(in: spoken).count)
        let wanted = max(1, Int((Double(step.target) / Double(ScriptPromptBuilder.sentenceWords(for: request.voice))).rounded()))
        let how = step.isShorter ? ", keeping only what matters." : ", adding detail."
        lines.append("It has \(now) sentences now. Rewrite it as exactly \(wanted) complete sentences" + how)
        lines.append("The block:")
        lines.append(blocks[step.index])
        return lines.joined(separator: "\n")
    }

    /// The last sentence of a block, for the next one to follow from.
    private static func tail(of block: String) -> String {
        WritingText.sentences(in: CueParser.stripCues(block)).last ?? ""
    }
}
