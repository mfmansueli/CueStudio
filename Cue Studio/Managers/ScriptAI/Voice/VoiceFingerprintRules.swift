//
//  VoiceFingerprintRules.swift
//  Cue Studio
//

import Foundation

/// What was measured of the creator's writing (`VoiceFingerprint`), told to the model as two short rules and checked on the script it writes. A
/// small model copies the surface of a few examples but misses habits it was never told, like how long their sentences run or how rarely they
/// shout. The rules are said only for what the creator didn't answer themself, and only for scripts in the language that was measured.
nonisolated enum VoiceFingerprintRules {
    /// A script this far from the creator's sentence length (a share of it) is noted.
    static let lengthTolerance = 0.45
    /// Sentences a script needs before its average means something.
    static let minimumSentences = 4

    /// The lines of the brief, empty when nothing was imported or too little to be a habit.
    static func lines(for voice: CreatorVoice) -> [String] {
        guard let fingerprint = voice.fingerprint, fingerprint.isReliable else { return [] }
        var lines: [String] = []
        if voice.style.sentences == nil, !WritingLexicon.isUnspaced(fingerprint.language) {
            lines.append("Their sentences average about \(Int(fingerprint.wordsPerSentence.rounded())) words.")
        }
        if fingerprint.exclamationShare <= 0.03, fingerprint.words >= 200 {
            lines.append("They almost never use exclamation marks.")
        } else if fingerprint.questionShare >= 0.25 {
            lines.append("They often ask the viewer a question.")
        }
        return lines
    }

    /// How the script drifts from what was measured, in kinds that only count (`VoiceViolation.isSoft`): none when nothing was imported or the
    /// script is in another language.
    static func drift(in spoken: String, voice: CreatorVoice, language: CueLanguage?) -> [VoiceViolation] {
        guard let fingerprint = voice.fingerprint, fingerprint.isReliable else { return [] }
        let code = language?.locale.language.languageCode?.identifier ?? WritingText.language(of: spoken)
        guard fingerprint.applies(toLanguage: code) else { return [] }
        let sentences = WritingText.sentences(in: spoken, language: code)
        guard sentences.count >= minimumSentences else { return [] }
        var found: [VoiceViolation] = []
        if !WritingLexicon.isUnspaced(code), fingerprint.wordsPerSentence >= 4 {
            let words = WritingText.words(in: spoken, language: code).count
            let average = Double(words) / Double(sentences.count)
            if abs(average - fingerprint.wordsPerSentence) / fingerprint.wordsPerSentence > lengthTolerance {
                found.append(VoiceViolation(
                    kind: .sentenceLength,
                    detail: "Its sentences average \(Int(average.rounded())) words; this creator's average about \(Int(fingerprint.wordsPerSentence.rounded())): write sentences of that length."
                ))
            }
        }
        let exclamations = sentences.filter(WritingText.isExclamation).count
        if fingerprint.exclamationShare <= 0.03, Double(exclamations) / Double(sentences.count) >= 0.3 {
            found.append(VoiceViolation(
                kind: .exclamation,
                detail: "It has \(exclamations) exclamation marks in \(sentences.count) sentences; this creator almost never uses them: end sentences with full stops."
            ))
        }
        return found
    }
}
