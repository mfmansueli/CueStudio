//
//  PostCaption.swift
//  Cue Studio
//

import Foundation
import NaturalLanguage

/// The caption Cue copies for a post (13.3-6): the script's hook (its first spoken sentence, a second one when the first is short), then the
/// title, and #ad when the video has a brand. The creator can still edit it before it's copied again. A video without a script has only #ad,
/// when sponsored.
nonisolated enum PostCaption {
    static let adTag = "#ad"
    /// A hook longer than this is cut at a word, with "…": a caption's first line is what shows under the video.
    static let hookLimit = 150
    /// A first sentence this short ("Stop.") takes the next one with it.
    static let shortSentence = 40

    static func text(scriptText: String?, title: String, isSponsored: Bool) -> String {
        let hook = scriptText.flatMap(hook(of:))
        let title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        // The hook may already say the title; then the title isn't repeated.
        let showsTitle = !title.isEmpty && !(hook?.localizedCaseInsensitiveContains(title) ?? false)
        let last = [showsTitle ? title : nil, isSponsored ? adTag : nil].compactMap { $0 }.joined(separator: " ")
        return [hook, last.isEmpty ? nil : last].compactMap { $0 }.joined(separator: "\n\n")
    }

    /// The first spoken sentence of the script (cues and notes left out), with the next when it is short.
    static func hook(of text: String) -> String? {
        guard let paragraph = CueParser.paragraphs(in: CueParser.stripCues(text)).first(where: { !$0.isEmpty }) else { return nil }
        let tokenizer = NLTokenizer(unit: .sentence)
        tokenizer.string = paragraph
        var sentences: [String] = []
        tokenizer.enumerateTokens(in: paragraph.startIndex..<paragraph.endIndex) { range, _ in
            sentences.append(paragraph[range].trimmingCharacters(in: .whitespacesAndNewlines))
            return sentences.count < 2
        }
        guard var hook = sentences.first, !hook.isEmpty else { return nil }
        if hook.count < shortSentence, sentences.count > 1, hook.count + sentences[1].count < hookLimit {
            hook += " " + sentences[1]
        }
        guard hook.count > hookLimit else { return hook }
        let cut = hook.prefix(hookLimit)
        let words = cut.split(separator: " ").dropLast()
        return (words.isEmpty ? String(cut) : words.joined(separator: " ")) + "…"
    }
}
