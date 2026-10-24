//
//  ScriptSpelling.swift
//  Cue Studio
//

import Foundation

/// What the script lends to the words that were heard in a take.
///
/// The voice always decides **what was said and when**: improvised words stay, skipped lines never
/// appear, a different number or a negation is never replaced. The script only decides **how a
/// heard word is written** (spelling, accents, capitals, punctuation), and how much it is trusted
/// depends on the take:
/// - **Read from the script** (most heard words line up with it, in order): the recognizer's slips
///   are fixed. Short words that sit between words that line up are spelled as written, and a word
///   (or two) that differs from the script's by a letter or two between words that line up is
///   written as the script has it ("mostra" → "mostrar").
/// - **Improvised** (little lines up): only words that line up reliably take the script's spelling,
///   and a heard word is replaced only when it is nearly the same word.
/// **Numbers** are the script's when they are the same number written another way ("3" for "ba", "seks" for "6", "2 00 6"
/// for "2006"); a different one ("seventy" for "seventeen") is never replaced.
/// **Names.** A recognizer often writes a name it doesn't know as other words ("Jean Carlos disse que ela" for "Giancarlo
/// Fisichella"). When the take was read from the script, heard words that sound like a name of the script (`ScriptNames`,
/// `SoundAlignment`) are written as the name.
/// **Mixed languages.** A recognizer listens in one language, so an English phrase inside a Portuguese
/// take comes out as Portuguese-sounding words that mean nothing. When the take was read from the
/// script and the script has a phrase clearly in another language (`LanguageDetector.isForeign`)
/// where the voice gave about as many words that sound like it, the phrase is written as the script has it.
/// Words are compared by `WordTokenizer.key` (case, accents, width and the letters recognizers
/// write in more than one way are folded), so Arabic, Hindi, Japanese, Chinese and Thai are
/// compared the same way as Latin scripts.
nonisolated enum ScriptSpelling {
    struct Result: Equatable, Sendable {
        var words: [CaptionWord]
        /// Most of what was heard lines up with the script: the take was read from it.
        var followsScript: Bool
        /// Heard words that line up with the script, 0 to 1.
        var coverage: Double
    }

    /// Share of the heard words that must line up for the take to count as read from the script.
    static let followingCoverage = 0.6
    /// Fewest heard words, and fewest matches, before a take can count as read from the script.
    static let followingMinimumWords = 4
    static let followingMinimumMatches = 3
    /// Longest gap, in words, that is corrected word by word.
    static let longestGap = 3
    /// Longest stretch, in words, of a phrase in another language that is written as the script has it.
    static let longestForeignGap = 8
    /// How alike two words must be (1 is identical) for the heard one to be written as the script's.
    static let similarity = (improvised: 0.75, following: 0.65)
    /// How alike two stretches must be when the same letters are split into a different number of words.
    static let stretchSimilarity = (improvised: 0.8, following: 0.7)
    /// Fewest letters in a word that may be replaced by a similar one, in spaced and unspaced scripts.
    static let minimumLetters = (spaced: 4, unspaced: 2)
    /// Most letters in a stretch re-split into other words.
    static let stretchLetters = 2...12
    /// How alike a phrase of the script in another language and the words heard for it must sound: the recognizer wrote
    /// what it heard in its own language's spelling, not something else that was said.
    static let foreignLikeness = 0.5
    /// How alike heard words and a name of the script must sound for the name to be written.
    static let nameLikeness = 0.65
    /// Longest stretch, in words on either side, searched for names: a misheard name leaves a short one.
    static let longestNameGap = 12

    /// What a stretch between words that line up is corrected with.
    private struct Context {
        let following: Bool
        let language: CueLanguage?
        /// `ScriptNames.keys` of the script.
        let names: Set<String>
        /// Reads numbers spelled out in the take's language ("seventeen"), so they are never taken for other words.
        let spelled: NumberFormatter?
    }

    /// `heard` with the script's spelling where it applies; the same words and times, except that a
    /// stretch re-split into other words shares its time (and is marked estimated).
    static func apply(to heard: [CaptionWord], script: String, language: CueLanguage? = nil) -> Result {
        let written = CaptionText.words(in: CueParser.stripCues(script), language: language)
        guard !heard.isEmpty, !written.isEmpty else { return Result(words: heard, followsScript: false, coverage: 0) }
        let heardKeys = heard.map { WordAlignment.key($0.text) }
        let writtenKeys = written.map(WordAlignment.key)
        let pairs = WordAlignment.matches(heardKeys, writtenKeys)
        let coverage = Double(pairs.count) / Double(heard.count)
        let follows = heard.count >= followingMinimumWords && pairs.count >= followingMinimumMatches && coverage >= followingCoverage
        let anchors = follows ? trusted(pairs, keys: heardKeys) : WordAlignment.reliable(pairs, keys: heardKeys)
        let context = Context(
            following: follows, language: language, names: follows ? ScriptNames.keys(in: script, language: language) : [],
            spelled: language.map(spellOutReader(in:))
        )

        var words: [CaptionWord] = []
        var heardFrom = 0
        var writtenFrom = 0
        let end = WordAlignment.Match(first: heard.count, second: written.count)
        for anchor in anchors + [end] {
            guard anchor.first >= heardFrom, anchor.second >= writtenFrom else { continue }
            words += corrected(Array(heard[heardFrom..<anchor.first]), toward: Array(written[writtenFrom..<anchor.second]), context: context)
            if anchor.first < heard.count {
                var word = heard[anchor.first]
                word.text = written[anchor.second]
                words.append(word)
            }
            heardFrom = anchor.first + 1
            writtenFrom = anchor.second + 1
        }
        return Result(words: withoutRepeatedMarks(words), followsScript: follows, coverage: coverage)
    }

    /// `words` without a mark the recognizer wrote on its own ("。") right after a word whose closing marks already hold it, as
    /// a word taking the script's spelling does ("2002）。" then "。").
    private static func withoutRepeatedMarks(_ words: [CaptionWord]) -> [CaptionWord] {
        var kept: [CaptionWord] = []
        for word in words {
            let mark = word.text.trimmingCharacters(in: .whitespaces)
            let endsWith = kept.last.map { String($0.text.reversed().prefix { !$0.isLetter && !$0.isNumber }) } ?? ""
            if !mark.isEmpty, WordAlignment.key(mark).isEmpty, endsWith.contains(mark) { continue }
            kept.append(word)
        }
        return kept
    }

    /// The matches to trust in a take read from the script: the reliable ones, and a short word
    /// whose neighbor in the script and in the voice has as many words between them (the two
    /// agree on the structure, so it isn't a chance match).
    static func trusted(_ pairs: [WordAlignment.Match], keys: [String]) -> [WordAlignment.Match] {
        let reliable = Set(WordAlignment.reliable(pairs, keys: keys).map(\.first))
        return pairs.enumerated().filter { index, pair in
            if reliable.contains(pair.first) { return true }
            func agrees(with other: WordAlignment.Match?) -> Bool {
                guard let other else { return false }
                let heardGap = abs(pair.first - other.first) - 1
                let writtenGap = abs(pair.second - other.second) - 1
                return heardGap == writtenGap && heardGap <= longestGap - 1
            }
            return agrees(with: index > 0 ? pairs[index - 1] : nil) || agrees(with: index + 1 < pairs.count ? pairs[index + 1] : nil)
        }
        .map(\.element)
    }

    // MARK: - Between the words that line up

    /// The heard words between two matches, written as the script has them when they are nearly the
    /// same words, the same number or a name heard as other words. Nothing changes when the voice and the script say
    /// different things there.
    private static func corrected(_ heard: [CaptionWord], toward written: [String], context: Context, byName: Bool = true) -> [CaptionWord] {
        guard !heard.isEmpty, !written.isEmpty else { return heard }
        if let numbered = atTheSameNumber(heard, written, context: context) { return numbered }
        if context.following, let language = context.language, abs(heard.count - written.count) <= 1, heard.count <= longestForeignGap,
           written.count <= longestForeignGap, LanguageDetector.isForeign(written, to: language.languageCode),
           SoundKey.likeness(heard.map(\.text), written) >= foreignLikeness {
            return rewritten(heard, as: written)
        }
        if byName, context.following, !context.names.isEmpty, heard.count <= longestNameGap, written.count <= longestNameGap,
           let named = withNames(heard, written, context: context) {
            return named
        }
        guard heard.count <= longestGap, written.count <= longestGap else { return heard }
        let wordLimit = context.following ? similarity.following : similarity.improvised
        if heard.count == written.count {
            return zip(heard, written).map { word, spelling in
                var word = word
                if isNearlyTheSame(word.text, spelling, limit: wordLimit, context: context) { word.text = spelling }
                return word
            }
        }
        // The same letters split into more or fewer words ("news paper" / "newspaper").
        let heardLetters = heard.map { WordAlignment.key($0.text) }.joined()
        let writtenLetters = written.map(WordAlignment.key).joined()
        guard stretchLetters.contains(heardLetters.count), stretchLetters.contains(writtenLetters.count),
              abs(heardLetters.count - writtenLetters.count) <= 1,
              !hasDigit(heardLetters), !hasDigit(writtenLetters),
              ratio(heardLetters, writtenLetters) >= (context.following ? stretchSimilarity.following : stretchSimilarity.improvised),
              let first = heard.first, let last = heard.last else { return heard }
        return share(written, over: TimeSpan(start: first.start, end: max(first.start, last.end)))
    }

    // MARK: - Numbers

    /// `heard` with a number the script writes another way written as the script has it: the whole stretch when both say the
    /// same numbers ("3 cốc" / "ba cốc"), or a run of digits the recognizer cut up ("2 00 6" / "(2006)") with the words around
    /// it corrected on their own. Nil when no number is the same.
    private static func atTheSameNumber(_ heard: [CaptionWord], _ written: [String], context: Context) -> [CaptionWord]? {
        let heardTexts = heard.map(\.text)
        guard heardTexts.contains(where: hasDigit) || written.contains(where: hasDigit) else { return nil }
        let spoken = { (words: [String]) in words.flatMap { WordTokenizer.matchingKeys(of: $0, language: context.language) } }
        if heardTexts.map(WordAlignment.key) != written.map(WordAlignment.key), spoken(heardTexts) == spoken(written) {
            return rewritten(heard, as: written)
        }
        guard let heardRun = digitRun(in: heardTexts), let writtenRun = digitRun(in: written),
              digits(of: Array(heardTexts[heardRun])) == digits(of: Array(written[writtenRun])),
              heardRun.count > 1 || writtenRun.count > 1 || heardTexts[heardRun] != written[writtenRun] else { return nil }
        return corrected(Array(heard[..<heardRun.lowerBound]), toward: Array(written[..<writtenRun.lowerBound]), context: context)
            + rewritten(Array(heard[heardRun]), as: Array(written[writtenRun]))
            + corrected(Array(heard[heardRun.upperBound...]), toward: Array(written[writtenRun.upperBound...]), context: context)
    }

    /// The first run of words that are digits, with the points and commas between them ("2", ".", "0", "1", "6").
    private static func digitRun(in words: [String]) -> Range<Int>? {
        let isDigits = { (word: String) in
            let key = WordAlignment.key(word)
            return !key.isEmpty && key.allSatisfy { $0.wholeNumberValue != nil }
        }
        guard let first = words.firstIndex(where: isDigits) else { return nil }
        var last = first
        var index = first + 1
        while index < words.count {
            if isDigits(words[index]) {
                last = index
            } else if !WordAlignment.key(words[index]).isEmpty {
                break
            }
            index += 1
        }
        return first..<(last + 1)
    }

    /// The digits of `words`, in order, whatever the script they are written in.
    private static func digits(of words: [String]) -> [Int] {
        words.flatMap { WordAlignment.key($0).compactMap(\.wholeNumberValue) }
    }

    /// Whether `word` is a number, in digits or spelled out in the take's language.
    private static func isNumber(_ word: String, context: Context) -> Bool {
        hasDigit(word) || number(word, context: context) != nil
    }

    /// The value of `word` when it is a number: digits in any script ("2006", "٢٠٠٦", "三"), or a number spelled out in the
    /// take's language ("seventeen", "ثلاثة").
    private static func number(_ word: String, context: Context) -> Double? {
        let key = WordAlignment.key(word)
        guard !key.isEmpty else { return nil }
        let values = key.map(\.wholeNumberValue)
        if values.allSatisfy({ $0 != nil }) { return values.compactMap { $0 }.reduce(0) { Double($0) * 10 + Double($1) } }
        let spelled = word.lowercased().trimmingCharacters(in: .punctuationCharacters.union(.whitespaces))
        return context.spelled?.number(from: spelled)?.doubleValue
    }

    private static func spellOutReader(in language: CueLanguage) -> NumberFormatter {
        let formatter = NumberFormatter()
        formatter.numberStyle = .spellOut
        formatter.locale = language.locale
        return formatter
    }

    // MARK: - Names

    /// `heard` with the stretches that sound like a name of the script written as the script has them (`SoundAlignment`), and
    /// the words between them corrected as any other; nil when no name was heard. Only names are written this way, never a word
    /// beside one, and numbers never pair.
    private static func withNames(_ heard: [CaptionWord], _ written: [String], context: Context) -> [CaptionWord]? {
        let numbers = Set((heard.map(\.text) + written).filter { isNumber($0, context: context) })
        let blocks = SoundAlignment.blocks(heard.map(\.text), written, least: nameLikeness) { stretch in
            !stretch.contains(where: numbers.contains)
        }
        .filter { block in written[block.written].allSatisfy { context.names.contains(WordAlignment.key($0)) } }
        guard !blocks.isEmpty else { return nil }
        var result: [CaptionWord] = []
        var heardFrom = 0
        var writtenFrom = 0
        for block in blocks {
            result += corrected(
                Array(heard[heardFrom..<block.heard.lowerBound]), toward: Array(written[writtenFrom..<block.written.lowerBound]),
                context: context, byName: false
            )
            result += rewritten(Array(heard[block.heard]), as: Array(written[block.written]))
            heardFrom = block.heard.upperBound
            writtenFrom = block.written.upperBound
        }
        return result + corrected(Array(heard[heardFrom...]), toward: Array(written[writtenFrom...]), context: context, byName: false)
    }

    /// `heard` written as `written`: word for word in the voice's own times when there are as many,
    /// else the words share the stretch the voice took (a guess, so marked estimated).
    private static func rewritten(_ heard: [CaptionWord], as written: [String]) -> [CaptionWord] {
        guard heard.count != written.count, let first = heard.first, let last = heard.last else {
            return zip(heard, written).map { word, spelling in
                var word = word
                word.text = spelling
                return word
            }
        }
        return share(written, over: TimeSpan(start: first.start, end: max(first.start, last.end)))
    }

    /// Whether the heard word is the script's word with a slip or two. Digits are only ever the same number spelled out ("5"
    /// for "five"), and a number never another ("seventy" for "seventeen"). Words that are numbers too are otherwise compared
    /// by their letters like any word: "ثلاثة" is "ثلاث", but "einen" isn't "ein", nor "un" "una" (articles that also count one).
    private static func isNearlyTheSame(_ heard: String, _ written: String, limit: Double, context: Context) -> Bool {
        let heardKey = WordAlignment.key(heard)
        let writtenKey = WordAlignment.key(written)
        let heardNumber = number(heard, context: context)
        let writtenNumber = number(written, context: context)
        if hasDigit(heardKey) || hasDigit(writtenKey) { return heardNumber != nil && heardNumber == writtenNumber }
        if let heardNumber, let writtenNumber, heardNumber != writtenNumber { return false }
        let unspaced = WordSegmenter.containsUnspacedScript(heardKey) || WordSegmenter.containsUnspacedScript(writtenKey)
        let least = unspaced ? minimumLetters.unspaced : minimumLetters.spaced
        guard heardKey.count >= least, writtenKey.count >= least else { return false }
        return ratio(heardKey, writtenKey) >= limit
    }

    /// `words` one after the other over `span`, each as long as its share of the letters. The time
    /// is a guess, so the words are marked estimated.
    private static func share(_ words: [String], over span: TimeSpan) -> [CaptionWord] {
        let weights = words.map { Double(max(1, WordAlignment.key($0).count)) }
        let total = weights.reduce(0, +)
        var cursor = span.start
        return zip(words, weights).map { word, weight in
            let end = cursor + span.duration * weight / total
            defer { cursor = end }
            return CaptionWord(text: word, start: cursor, end: end, isEstimated: true)
        }
    }

    private static func hasDigit(_ text: String) -> Bool {
        text.contains(where: \.isNumber)
    }

    // MARK: - Similarity

    /// How alike two words are, 0 to 1: one minus the edits it takes to turn one into the other
    /// over the longer one's length.
    static func ratio(_ first: String, _ second: String) -> Double {
        let a = Array(first)
        let b = Array(second)
        guard !a.isEmpty || !b.isEmpty else { return 1 }
        guard !a.isEmpty, !b.isEmpty else { return 0 }
        var previous = Array(0...b.count)
        for i in 1...a.count {
            var row = [i] + [Int](repeating: 0, count: b.count)
            for j in 1...b.count {
                row[j] = a[i - 1] == b[j - 1] ? previous[j - 1] : min(previous[j - 1], previous[j], row[j - 1]) + 1
            }
            previous = row
        }
        return 1 - Double(previous[b.count]) / Double(max(a.count, b.count))
    }
}
