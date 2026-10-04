//
//  ScriptShape.swift
//  Cue Studio
//

import Foundation

/// The "Shaped" side of a script page (v26): the text as sections (HOOK, BODY, CTA…) with the
/// advice that goes with them. Shaping never rewrites the words: it reads them. A tip is advice the
/// creator can take ("Fix", "Split") or wave off.
nonisolated struct ScriptShape: Equatable, Sendable {
    struct Section: Equatable, Identifiable, Sendable {
        let label: String
        let paragraphs: [String]
        /// Where the section starts, as the index of its first paragraph.
        let firstParagraph: Int
        let isHook: Bool
        /// The closing block the script doesn't have yet: "No CTA yet · Suggest one".
        let isMissingCTA: Bool

        var id: Int { firstParagraph }
        var text: String { paragraphs.joined(separator: "\n\n") }
    }

    enum Tip: Equatable, Hashable, Sendable {
        /// The opening runs longer than a viewer gives it.
        case longHook(seconds: Int)
        case longSentence(String)

        /// What a dismissal remembers.
        var id: String {
            switch self {
            case .longHook: "hook"
            case .longSentence: "long"
            }
        }
    }

    /// A sentence longer than this many words is hard to read out loud.
    static let longSentenceWords = 24

    /// What a call to action sounds like; a script that closes on one has a CTA.
    private static let ctaWords = ["follow", "comment", "save", "share", "link", "try it", "let me know", "subscribe", "tell me", "bio"]

    let sections: [Section]
    let hookTip: Tip?
    let bodyTip: Tip?

    /// - Parameters:
    ///   - structure: the script's format; the generic one ("Talking video") calls the last
    ///     paragraph a CTA only when it sounds like one.
    ///   - suggestsCTA: whether a script with no call to action is told so.
    init(text: String, structure: ScriptStructure, speed: Double, suggestsCTA: Bool = true) {
        let paragraphs = CueParser.paragraphs(in: text)
        let closingLabel = structure.blocks.last ?? ""
        let isGeneric = structure.blocks == ScriptStructure.generic.blocks
        let hasCTA = !isGeneric || (paragraphs.count > 1 && Self.soundsLikeACTA(paragraphs[paragraphs.count - 1]))
        let middleLabel = structure.blocks.count > 2 ? structure.blocks[structure.blocks.count - 2] : closingLabel

        var labels = paragraphs.indices.map { structure.blockLabel(forParagraph: $0, of: paragraphs.count) }
        if isGeneric, !hasCTA, paragraphs.count > 1 {
            // The closing paragraph isn't a CTA: it is part of the body.
            labels[labels.count - 1] = middleLabel
        }

        var built: [Section] = []
        for (index, paragraph) in paragraphs.enumerated() {
            if let last = built.last, last.label == labels[index] {
                built[built.count - 1] = Section(
                    label: last.label, paragraphs: last.paragraphs + [paragraph], firstParagraph: last.firstParagraph,
                    isHook: last.isHook, isMissingCTA: false
                )
            } else {
                built.append(Section(
                    label: labels[index], paragraphs: [paragraph], firstParagraph: index,
                    isHook: index == 0 && !structure.isSerious, isMissingCTA: false
                ))
            }
        }
        if suggestsCTA, isGeneric, !paragraphs.isEmpty, !hasCTA {
            built.append(Section(label: closingLabel, paragraphs: [], firstParagraph: paragraphs.count, isHook: false, isMissingCTA: true))
        }
        sections = built

        let hookSentence = paragraphs.first.flatMap { Self.sentences(in: $0).first } ?? ""
        let hookSeconds = ReadTime.seconds(for: hookSentence, speed: speed)
        hookTip = !structure.isSerious && hookSeconds > ScriptBlocks.hookTarget ? .longHook(seconds: Int(hookSeconds.rounded())) : nil
        let body = built.first { !$0.isHook && !$0.isMissingCTA }
        bodyTip = body?.paragraphs.lazy
            .flatMap { Self.sentences(in: $0) }
            .first { ReadTime.wordCount(in: $0) > Self.longSentenceWords }
            .map { .longSentence($0) }
    }

    // MARK: - Sentences

    static func sentences(in paragraph: String) -> [String] {
        var result: [String] = []
        paragraph.enumerateSubstrings(in: paragraph.startIndex..., options: .bySentences) { sentence, _, _, _ in
            if let sentence = sentence?.trimmingCharacters(in: .whitespacesAndNewlines), !sentence.isEmpty {
                result.append(sentence)
            }
        }
        return result
    }

    static func soundsLikeACTA(_ paragraph: String) -> Bool {
        ctaWords.contains { paragraph.localizedCaseInsensitiveContains($0) }
    }

    // MARK: - Fixes

    /// "Fix": the hook cut to its first eight words, which is all a viewer waits for.
    static func shortenedHook(in text: String) -> String {
        let lines = text.components(separatedBy: "\n")
        guard let index = lines.firstIndex(where: { !$0.trimmingCharacters(in: .whitespaces).isEmpty }) else { return text }
        let line = lines[index]
        guard let first = sentences(in: line).first, let range = line.range(of: first) else { return text }
        let words = first.split(whereSeparator: \.isWhitespace).prefix(8).joined(separator: " ")
        let short = words.trimmingCharacters(in: CharacterSet(charactersIn: ",;:")) + "."
        return text.replacingOccurrences(of: line, with: line.replacingCharacters(in: range, with: short))
    }

    /// "Split": the sentence breaks at its first comma into two.
    static func splitting(_ sentence: String, in text: String) -> String {
        guard let comma = sentence.range(of: ", ") else { return text }
        let split = sentence.replacingCharacters(in: comma, with: ". ")
        return text.replacingOccurrences(of: sentence, with: split)
    }

    /// The line "Suggest one" adds.
    static var suggestedCTA: String { String(localized: "Save this for later — and follow for more.") }

    static func addingCTA(to text: String) -> String {
        text.trimmingCharacters(in: .whitespacesAndNewlines) + "\n" + suggestedCTA
    }
}
