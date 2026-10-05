//
//  OutputLanguageCheck.swift
//  Cue Studio
//

import Foundation
import NaturalLanguage

/// Whether what the model wrote is in the language it was asked for. A model told to polish a
/// Portuguese script can answer in English, and one told to translate can hand the text back
/// untouched; neither may replace the creator's words as if it had worked. It only says "no" when
/// the text is long enough to tell and clearly in another language: a short line, a mix of languages
/// or a close relative (Danish and Norwegian) always passes, so a good result is never refused.
nonisolated enum OutputLanguageCheck {
    /// Fewest words (two letters to a word in scripts written without spaces) before a text says anything about its language.
    static let minimumWords = 10
    /// How sure Natural Language must be of another language to refuse the text.
    static let rejectConfidence = 0.85
    /// Chinese writing systems share most characters: refusing one for the other asks for more certainty.
    static let scriptRejectConfidence = 0.95
    /// Share of the text that is enough to call the expected language present.
    static let presentConfidence = 0.15

    /// Languages close enough that the recognizer swaps them on short texts; any of them passes for the others.
    private static let families: [Set<String>] = [["da", "nb", "nn", "no"], ["id", "ms"]]

    static func isPlausible(_ text: String, in expected: CueLanguage) -> Bool {
        isPlausible(text, in: expected.locale.language)
    }

    static func isPlausible(_ text: String, in expected: Locale.Language) -> Bool {
        let spoken = CueParser.stripCues(text)
        guard wordCount(of: spoken) >= minimumWords, let code = expected.languageCode?.identifier else { return true }
        let recognizer = NLLanguageRecognizer()
        recognizer.processString(spoken)
        let hypotheses = recognizer.languageHypotheses(withMaximum: 3).sorted { $0.value > $1.value }
        guard let top = hypotheses.first, top.key != .undetermined else { return true }
        let heard = Locale.Language(identifier: top.key.rawValue)
        let heardCode = heard.languageCode?.identifier ?? ""
        if code == "zh", heardCode == "zh" {
            return !isOtherChineseScript(heard, than: expected) || top.value < scriptRejectConfidence
        }
        if heardCode == code || families.contains(where: { $0.contains(code) && $0.contains(heardCode) }) { return true }
        let expectedShare = hypotheses.first { Locale.Language(identifier: $0.key.rawValue).languageCode?.identifier == code }?.value ?? 0
        return expectedShare >= presentConfidence || top.value < rejectConfidence
    }

    private static func isOtherChineseScript(_ heard: Locale.Language, than expected: Locale.Language) -> Bool {
        guard let heardLanguage = CueLanguage.matching(language: heard),
              let expectedLanguage = CueLanguage.matching(language: expected) else { return false }
        return heardLanguage != expectedLanguage
    }

    private static func wordCount(of text: String) -> Int {
        if WordSegmenter.containsUnspacedScript(text) { return text.filter(\.isLetter).count / 2 }
        return text.split(whereSeparator: \.isWhitespace).filter { $0.contains(where: \.isLetter) }.count
    }
}
