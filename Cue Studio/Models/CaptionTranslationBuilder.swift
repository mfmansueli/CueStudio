//
//  CaptionTranslationBuilder.swift
//  Cue Studio
//

import Foundation

/// Translation of captions sentence by sentence, for context, broken back into lines that read
/// comfortably. A translated sentence shows over its original's time, shared by length: languages
/// don't say things in the same order or length, so no word of it is tied to the voice.
nonisolated enum CaptionTranslationBuilder {
    /// A silence this long ends a sentence even without punctuation.
    static let sentenceGap: TimeInterval = 1
    /// Original lines translated together at most.
    static let linesPerSentence = 4
    /// Letters per translated line at most (fewer for languages without spaces).
    static let lineLength = 32
    static let unspacedLineLength = 16

    /// The original lines in sentences: a new one after a sentence ends, after a pause, when the
    /// recording changes (a montage), or when it has four lines.
    static func sentences(from captions: [CaptionCue]) -> [[CaptionCue]] {
        var result: [[CaptionCue]] = []
        var current: [CaptionCue] = []
        let ordered = captions.filter { !$0.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .sorted { ($0.sourceID?.uuidString ?? "", $0.start) < ($1.sourceID?.uuidString ?? "", $1.start) }
        for cue in ordered {
            if let last = current.last,
               last.sourceID != cue.sourceID || cue.start - last.end > sentenceGap || endsSentence(last.text) || current.count >= linesPerSentence {
                result.append(current)
                current = []
            }
            current.append(cue)
        }
        if !current.isEmpty { result.append(current) }
        return result
    }

    /// What a sentence says, to translate.
    static func text(of sentence: [CaptionCue]) -> String {
        CaptionText.joined(sentence.map(\.text))
    }

    /// `translated` (a sentence) as lines over the sentence's time.
    static func lines(_ translated: String, for sentence: [CaptionCue]) -> [TranslatedCaptionLine] {
        guard let first = sentence.first, let last = sentence.last else { return [] }
        let words = CaptionText.words(in: translated.trimmingCharacters(in: .whitespacesAndNewlines))
        guard !words.isEmpty else { return [] }
        var packed: [[String]] = []
        var current: [String] = []
        for word in words {
            let limit = WordSegmenter.containsUnspacedScript(word) ? unspacedLineLength : lineLength
            if !current.isEmpty, CaptionText.length(current + [word]) > limit {
                packed.append(current)
                current = []
            }
            current.append(word)
        }
        if !current.isEmpty { packed.append(current) }
        let total = max(1, packed.reduce(0) { $0 + CaptionText.length($1) })
        let duration = max(0, last.end - first.start)
        var start = first.start
        return packed.map { line in
            let length = duration * Double(CaptionText.length(line)) / Double(total)
            defer { start += length }
            return TranslatedCaptionLine(
                cueIDs: sentence.map(\.id), sourceText: text(of: sentence), text: CaptionText.joined(line),
                start: start, end: start + length, sourceID: first.sourceID
            )
        }
    }

    /// A new translation with the creator's corrections kept: a sentence whose lines were
    /// corrected, and whose original hasn't changed, keeps them unless `replacingRevised`.
    static func merged(
        _ new: [TranslatedCaptionLine], keeping old: CaptionTranslation?, captions: [CaptionCue], replacingRevised: Bool
    ) -> [TranslatedCaptionLine] {
        guard let old, !replacingRevised else { return new }
        let outdated = Set(old.outdatedLines(against: captions).map(\.id))
        let kept = Dictionary(grouping: old.lines.filter { $0.isRevised && !outdated.contains($0.id) }) { $0.cueIDs }
        var result: [TranslatedCaptionLine] = []
        var used: Set<[UUID]> = []
        for line in new {
            if let corrected = kept[line.cueIDs] {
                if used.insert(line.cueIDs).inserted { result += corrected }
            } else {
                result.append(line)
            }
        }
        return result
    }

    private static func endsSentence(_ text: String) -> Bool {
        guard let last = text.trimmingCharacters(in: .whitespaces).last else { return false }
        return ".!?。！？…؟।".contains(last)
    }
}
