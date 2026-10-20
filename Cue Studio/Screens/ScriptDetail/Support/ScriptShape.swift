//
//  ScriptShape.swift
//  Cue Studio
//

import Foundation

/// A script read as sections (HOOK, BODY, CTA…), for the teleprompter's markers. It never rewrites the words: it reads them.
nonisolated struct ScriptShape: Equatable, Sendable {
    struct Section: Equatable, Identifiable, Sendable {
        let label: String
        let paragraphs: [String]
        /// Where the section starts, as the index of its first paragraph.
        let firstParagraph: Int
        let isHook: Bool

        var id: Int { firstParagraph }
    }

    /// What a call to action sounds like; a script that closes on one has a CTA.
    private static let ctaWords = ["follow", "comment", "save", "share", "link", "try it", "let me know", "subscribe", "tell me", "bio"]

    let sections: [Section]

    /// - Parameters:
    ///   - structure: the script's format; the generic one ("Talking video") calls the last
    ///     paragraph a CTA only when it sounds like one.
    init(text: String, structure: ScriptStructure) {
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
                    isHook: last.isHook
                )
            } else {
                built.append(Section(
                    label: labels[index], paragraphs: [paragraph], firstParagraph: index,
                    isHook: index == 0 && !structure.isSerious
                ))
            }
        }
        sections = built
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
}
