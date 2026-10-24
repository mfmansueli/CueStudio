//
//  CaptionBlocking.swift
//  Cue Studio
//

import CoreGraphics
import Foundation

/// Caption lines cut again into what shows at once, by a format (`CaptionFormat`): the same words, with the corrections and
/// times they have, grouped anew. A block ends where the speech does (a sentence's end, a long pause), likes to end at a comma
/// or a short pause, never ends on a word that leans on the next ("the", "de", "and") when it can help it, and ends before it
/// would take more lines than the format allows in the style's own type at its own size (`CaptionCollectionRenderer.measure`),
/// so nothing shrinks to fit: only a word wider than the whole room, alone in its block, is drawn smaller. A block stays long
/// enough to be read when the silence after it leaves room.
///
/// What a creator decided stays: lines split or joined by hand (`CaptionCue.keepsBlock`) or broken onto a new line by hand
/// (`CaptionCue.lineBreaks`) are left as they are, as are empty lines, and the lines of another recording or with a style of
/// their own are never mixed with the rest. A run of lines with no measured word times is never shown one word at a time
/// (that would pretend to follow the voice): it gets short phrases.
nonisolated enum CaptionBlocking {
    /// A silence this long always ends a block.
    static let pauseBreak: TimeInterval = 0.6
    /// A silence this long, like a comma, is where a short phrase likes to end.
    static let softPause: TimeInterval = 0.3
    /// Shortest a block stays when the silence after it leaves room (about 5/6 s, as subtitles do).
    static let shortestBlock: TimeInterval = 0.8
    /// A silence shorter than this between two blocks is closed (subtitles close gaps under about half a second).
    static let linger: TimeInterval = 0.5
    /// Characters per second a block is given time for, when the silence after it allows (adult subtitles: 17 to 20).
    static let readingSpeed: Double = 20

    /// The frame the format measures in: the take's shape (the type scales with the frame, so any size of it measures alike).
    static func frame(widthOverHeight ratio: Double) -> CGSize {
        CGSize(width: 1080, height: (1080 / max(0.1, ratio)).rounded())
    }

    /// `lines` cut into blocks by `format`, measured in `settings`' type on `frame`.
    static func blocks(_ lines: [CaptionCue], format: CaptionFormat, settings: CaptionSettings, frame: CGSize) -> [CaptionCue] {
        var result: [CaptionCue] = []
        var run: [CaptionCue] = []
        func flush() {
            result += regrouped(run, format: format, settings: settings, frame: frame)
            run = []
        }
        for line in lines {
            if line.keepsBlock || words(of: line).isEmpty || !line.lineBreaks.isEmpty {
                flush()
                result.append(line)
                continue
            }
            if let last = run.last, last.sourceID != line.sourceID || last.lineStyle != line.lineStyle || line.start < last.start {
                flush()
            }
            run.append(line)
        }
        flush()
        return result
    }

    // MARK: - Private

    private struct Token {
        let word: CaptionWord
        /// The line of the run it came from.
        let line: Int
    }

    private static func regrouped(_ run: [CaptionCue], format: CaptionFormat, settings: CaptionSettings, frame: CGSize) -> [CaptionCue] {
        guard !run.isEmpty else { return [] }
        let styled = CaptionCollectionRenderer.styled(settings, for: run[0].lineStyle)
        let tokens = run.enumerated().flatMap { index, line in words(of: line).map { Token(word: $0, line: index) } }
        let groups: [Range<Int>]
        if format == .oneWord, run.allSatisfy(\.hasWordTiming) {
            groups = tokens.indices.map { $0..<($0 + 1) }
        } else {
            groups = phrases(tokens, format: format == .oneWord ? .phrase : format, settings: styled, frame: frame)
        }
        var used = Set<UUID>()
        return groups.enumerated().map { position, range in
            let nextStart = position + 1 < groups.count ? tokens[groups[position + 1].lowerBound].word.start : nil
            return cue(tokens[range], nextStart: nextStart, run: run, used: &used)
        }
    }

    /// Where each block of `tokens` ends: after a sentence or a long pause; at a comma or a short pause once a short phrase says
    /// something; and before the next word would make it too wide or too long, without leaving a word that leans on the next.
    private static func phrases(_ tokens: [Token], format: CaptionFormat, settings: CaptionSettings, frame: CGSize) -> [Range<Int>] {
        var groups: [Range<Int>] = []
        var start = 0
        func text(_ range: Range<Int>) -> String { CaptionText.joined(tokens[range].map(\.word.text)) }
        for index in tokens.indices {
            guard index + 1 < tokens.count else {
                groups.append(start..<tokens.count)
                break
            }
            let word = tokens[index].word
            let next = tokens[index + 1].word
            let gap = next.start - word.end
            if endsSentence(word.text) || gap >= pauseBreak {
                groups.append(start..<(index + 1))
                start = index + 1
                continue
            }
            let count = index + 1 - start
            if format == .phrase, count >= 2, isSoftBreak(word.text) || gap >= softPause {
                groups.append(start..<(index + 1))
                start = index + 1
                continue
            }
            let candidate = start..<(index + 2)
            // A short phrase takes a second line only so a word isn't left alone on its own.
            let allowed = format == .phrase ? (count < 2 ? 2 : 1) : format.maxLines
            let measured = CaptionCollectionRenderer.measure(text(candidate), settings: settings, frame: frame)
            let fits = measured.map { $0.lines <= allowed && !$0.overlong } ?? true
            if fits, next.end - tokens[start].word.start <= format.longestBlock { continue }
            var end = index + 1
            if end - start > 1, leansOnNext(word.text) { end -= 1 }
            groups.append(start..<end)
            start = end
        }
        return groups.filter { !$0.isEmpty }
    }

    /// A block of `tokens`: its words and their times as they were. It shows as long as the line it closes did (or to its last
    /// word), longer when its words need the time to be read (`shortestBlock`, `readingSpeed`) and the silence after it allows,
    /// and up to the next block when only a breath (`linger`) separates them, so a sentence doesn't blink between blocks. The
    /// first block that starts a line keeps that line's identity, so a translation or a pick that pointed at the line points
    /// at where it starts.
    private static func cue(_ tokens: ArraySlice<Token>, nextStart: TimeInterval?, run: [CaptionCue], used: inout Set<UUID>) -> CaptionCue {
        let words = tokens.map(\.word)
        let lines = Array(Set(tokens.map(\.line))).sorted().map { run[$0] }
        let first = words[0]
        let last = words[words.count - 1]
        let text = CaptionText.joined(words.map(\.text))
        let closing = tokens.last.map { run[$0.line] }.flatMap { Self.words(of: $0).last == last ? $0.end : nil }
        let reading = max(shortestBlock, Double(text.count) / readingSpeed)
        var end = max(closing ?? last.end, first.start + reading)
        if let nextStart {
            end = nextStart - last.end < linger ? max(last.end, nextStart) : min(end, nextStart)
        }
        var cue = CaptionCue(
            text: text, start: first.start, end: max(end, first.start + CaptionCue.minimumDuration), words: words,
            origin: lines[0].origin, isRevised: lines.contains(where: \.isRevised),
            needsTimingReview: lines.contains(where: \.needsTimingReview)
        )
        cue.sourceID = lines[0].sourceID
        cue.lineStyle = lines[0].lineStyle
        if let opened = lines.first(where: { Self.words(of: $0).first == first && !used.contains($0.id) }) {
            cue.id = opened.id
            used.insert(opened.id)
        }
        return cue
    }

    /// A line's words with the times it has: the ones it keeps when they are its text (measured, or estimated once, so cutting
    /// again never moves a guessed time), else its words shared over its time (`CaptionCue.lineWords`).
    private static func words(of line: CaptionCue) -> [CaptionWord] {
        if !line.words.isEmpty, line.words.map(\.text) == CaptionText.words(in: line.text) { return line.words }
        return line.lineWords
    }

    /// A sentence ends with the word (abbreviations like "Dr." and initials don't).
    static func endsSentence(_ word: String) -> Bool {
        let trimmed = word.trimmingCharacters(in: CharacterSet(charactersIn: "\"'”’»)]"))
        guard let mark = trimmed.last, ".!?…。！？؟".contains(mark) else { return false }
        guard mark == "." else { return true }
        let bare = trimmed.dropLast().lowercased()
        if bare.count == 1, bare.first?.isLetter == true { return false }
        return !abbreviations.contains(String(bare))
    }

    /// A comma, a semicolon, a colon or a dash ends the word: a place a phrase likes to end.
    static func isSoftBreak(_ word: String) -> Bool {
        guard let mark = word.last else { return false }
        return ",;:—–、，؛،".contains(mark)
    }

    /// A word that belongs with the next one (an article, a preposition, a conjunction), in the languages that write them apart.
    static func leansOnNext(_ word: String) -> Bool {
        leaning.contains(word.lowercased().trimmingCharacters(in: .punctuationCharacters))
    }

    private static let abbreviations: Set<String> = [
        "dr", "dra", "sr", "sra", "srta", "mr", "mrs", "ms", "st", "prof", "profa", "vs", "etc", "jr", "mt", "no", "nº", "av", "pág",
    ]

    private static let leaning: Set<String> = [
        // English
        "a", "an", "the", "of", "to", "in", "on", "at", "for", "and", "or", "but", "with", "my", "your", "his", "her", "our", "their",
        // Portuguese
        "o", "os", "as", "um", "uma", "de", "do", "da", "dos", "das", "em", "no", "na", "nos", "nas", "e", "ou", "que", "para", "por",
        "com", "meu", "minha", "seu", "sua", "pra",
        // Spanish
        "el", "la", "los", "las", "una", "del", "y", "con", "mi", "tu", "su",
        // French
        "le", "les", "une", "des", "du", "et", "pour", "par", "avec", "au", "aux", "mon", "ma", "ton", "ta", "son", "sa",
        // Italian
        "il", "lo", "gli", "di", "della", "per",
        // German
        "der", "die", "das", "ein", "eine", "und", "oder", "mit", "von", "zu", "im", "für",
    ]
}
