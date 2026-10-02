//
//  ScriptLanguageRuns.swift
//  Cue Studio
//

import Foundation
import NaturalLanguage

/// A script split into stretches by the language each is written in, sentence by sentence: an
/// English opening followed by Portuguese is two stretches. Captions use it to listen to a take in
/// every language its script uses (`CaptionTranscriber`) and to take each stretch from the
/// recognizer that heard it (`MixedLanguageMerge`).
///
/// A sentence only counts as being in another language when it has enough words and Natural Language
/// is sure of it; a short or doubtful one ("Muito bem!") belongs to the stretch around it.
nonisolated enum ScriptLanguageRuns {
    /// A stretch of the script's words in one language.
    struct Run: Equatable, Sendable {
        /// ISO 639 code ("pt", "en").
        let code: String
        /// Indices into `Reading.words`.
        let words: Range<Int>
    }

    struct Reading: Equatable, Sendable {
        /// The script's spoken words (cues left out), in order.
        let words: [String]
        /// Empty when no sentence could be told apart (nothing to listen for but one language).
        let runs: [Run]
    }

    /// Fewest words in a sentence before its own language is trusted over its neighbors'.
    static let minimumSentenceWords = 3
    /// How sure Natural Language must be of a sentence's language.
    static let confidence = 0.75
    /// Fewest words in another language before it's worth listening to the take in it as well.
    static let minimumForeignWords = 3
    /// Most other languages a take is listened to in.
    static let maximumForeignLanguages = 2

    /// - Parameter language: the language the take is heard in, so unspaced scripts are cut the same way.
    static func reading(of script: String, language: CueLanguage? = nil) -> Reading {
        let spoken = CueParser.stripCues(script)
        var words: [String] = []
        var sentences: [(range: Range<Int>, code: String?)] = []
        let tokenizer = NLTokenizer(unit: .sentence)
        tokenizer.string = spoken
        tokenizer.enumerateTokens(in: spoken.startIndex..<spoken.endIndex) { range, _ in
            let sentence = String(spoken[range])
            let found = CaptionText.words(in: sentence, language: language).filter { WordAlignment.key($0).isEmpty == false }
            guard !found.isEmpty else { return true }
            let start = words.count
            words += found
            sentences.append((start..<words.count, confidentCode(of: sentence, wordCount: found.count)))
            return true
        }
        return Reading(words: words, runs: runs(of: sentences))
    }

    /// The codes of the other languages the script uses enough to be worth listening for, the most
    /// used first.
    static func foreignCodes(in reading: Reading, besides primary: String) -> [String] {
        var counts: [String: Int] = [:]
        for run in reading.runs where run.code != primary { counts[run.code, default: 0] += run.words.count }
        return counts
            .filter { $0.value >= minimumForeignWords }
            .sorted { $0.value == $1.value ? $0.key < $1.key : $0.value > $1.value }
            .prefix(maximumForeignLanguages)
            .map(\.key)
    }

    // MARK: - Reading a sentence

    private static func confidentCode(of sentence: String, wordCount: Int) -> String? {
        guard wordCount >= minimumSentenceWords else { return nil }
        let recognizer = NLLanguageRecognizer()
        recognizer.processString(sentence)
        guard let top = recognizer.languageHypotheses(withMaximum: 1).first,
              top.key != .undetermined, top.value >= confidence else { return nil }
        return Locale.Language(identifier: top.key.rawValue).languageCode?.identifier
    }

    /// Sentences joined into stretches; one nobody is sure of takes the language of the sentence
    /// before it (or, at the start, of the first one that has one).
    private static func runs(of sentences: [(range: Range<Int>, code: String?)]) -> [Run] {
        guard let first = sentences.compactMap(\.code).first else { return [] }
        var runs: [Run] = []
        var current = first
        for sentence in sentences {
            current = sentence.code ?? current
            if let last = runs.last, last.code == current {
                runs[runs.count - 1] = Run(code: current, words: last.words.lowerBound..<sentence.range.upperBound)
            } else {
                runs.append(Run(code: current, words: sentence.range))
            }
        }
        return runs
    }
}
