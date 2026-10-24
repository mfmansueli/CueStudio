//
//  SettledLastWord.swift
//  Cue Studio
//

import Foundation

/// The transcriber sometimes ends a result with its last word twice: as it first guessed it, closing the sentence, and as it
/// settled on it ("gezeichnet wurde. wurde", "sus planes de vida. viaje.", heard on an iPhone 15 Pro, iOS 27, in 3 of 100
/// people's readings, never in the dictation recognizer's). The voice said one word, so the two become one: the settled
/// spelling with the guess's closing mark, from the guess's start to the settled word's end. Only where writing has capitals,
/// since there a word starting in lowercase right after a sentence's end begins no new sentence, and only when the first guess
/// is a word (four letters or more, no inner period) that sounds like the settled one (`SoundKey`: the same first sound, and
/// `likeness` close), so a word after an abbreviation ("etc. too", "e.g. this", "Dr. who") stays.
nonisolated enum SettledLastWord {
    /// How alike the guess and the settled word sound, at least: "vida" and "viaje" are 0.4.
    static let likeness = 0.4

    /// `words`, one recognizer result, with a last word heard twice made one.
    static func applied(to words: [TimedWord]) -> [TimedWord] {
        guard words.count >= 2 else { return words }
        let guess = words[words.count - 2]
        let settled = words[words.count - 1]
        let guessed = SoundKey.of([guess.text])
        let said = SoundKey.of([settled.text])
        guard let mark = guess.text.last, endsSentence(mark), !guess.text.dropLast().contains("."),
              guess.text.filter(\.isLetter).count >= 4, settled.text.first(where: \.isLetter)?.isLowercase == true,
              guessed.first == said.first, ScriptSpelling.ratio(guessed, said) >= likeness else { return words }
        let text = settled.text.last.map(endsSentence) == true ? settled.text : settled.text + String(mark)
        let word = TimedWord(text: text, start: guess.start, end: settled.end, isEstimated: guess.isEstimated || settled.isEstimated)
        return words.dropLast(2) + [word]
    }

    private static func endsSentence(_ mark: Character) -> Bool {
        ".!?…".contains(mark)
    }
}
