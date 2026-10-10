//
//  IdeaBrief.swift
//  Cue Studio
//

import Foundation

/// One inspiration as one creative brief (Find inspiration): what the video is about (its headline), the angle that makes it worth watching, and a
/// first sentence that lets the creator hear it at once. The three are written together and travel together, from the roulette's card to the
/// composer and on to the script, so the script follows the angle and opens with (or near) the line instead of inventing its own.
///
/// The opening line is a suggestion to say, never a claim about the creator: no lived experience, result or number is put in their mouth.
nonisolated struct IdeaBrief: Hashable, Codable, Sendable {
    /// What the video is about: its headline, the idea's title ("Why saving feels harder than spending").
    var subject: String
    /// The perspective that makes it interesting, as a short instruction ("Explain one small habit that makes saving easier.").
    var angle: String
    /// A first sentence the creator could say ("Saving isn't just about willpower. It's about what you make automatic.").
    var openingLine: String
    /// The subtopic of the creator's topic it is about, when it is one ("Yoga & stretching").
    var subtopic: String?
    /// The language it is written in (a minimal identifier, "en"), when known.
    var language: String?
    /// How it looks at its topic (`IdeaAngle.rawValue`), when known: what a script written from it teaches the creator's taste (`IdeaTaste`).
    var angleKind: String?
    /// Which of the creator's topics it is about, the way `IdeaTaste` keeps topics (a first-flight niche's raw value, else the topic's label).
    var topicKey: String?

    init(
        subject: String, angle: String, openingLine: String, subtopic: String? = nil, language: String? = nil, angleKind: String? = nil,
        topicKey: String? = nil
    ) {
        self.subject = subject
        self.angle = angle
        self.openingLine = openingLine
        self.subtopic = subtopic
        self.language = language
        self.angleKind = angleKind
        self.topicKey = topicKey
    }

    /// What "Use this idea" puts in the composer: the whole brief, as text the creator can change. Never longer than the composer takes
    /// (`IdeaPromptDraft.maxCharacters`): a brief that is longer loses the end of its opening line, then of its angle, at a word, never
    /// in the middle of one (`fitted`).
    var composerText: String {
        let fitted = fitted()
        return String(fitted.layout.prefix(IdeaPromptDraft.maxCharacters))
    }

    /// The three parts as the composer holds them, each on its line; a part with nothing left in it has no line.
    private var layout: String {
        var lines = [subject]
        if !angle.isEmpty { lines.append(String(localized: "Angle: \(angle)", comment: "Find inspiration: the angle's line in the idea field")) }
        if !openingLine.isEmpty {
            lines.append(String(localized: "Open with: “\(openingLine)”", comment: "Find inspiration: the opening line's line in the idea field"))
        }
        return lines.joined(separator: "\n")
    }

    /// The brief made to fit `limit` characters once laid out for the composer: a second sentence goes first (the opening line's, then the angle's),
    /// then words from the end of the longer of the two, so neither is cut to nothing while the other runs on; the subject (the headline) is only
    /// shortened past `limit` itself. A part that was cut ends in "…", and never in half a word. What the card shows is this, so what the creator
    /// reads is what the field gets.
    func fitted(to limit: Int = IdeaPromptDraft.maxCharacters) -> IdeaBrief {
        var brief = self
        brief.subject = Self.trimmed(subject)
        brief.angle = Self.trimmed(angle)
        brief.openingLine = Self.trimmed(openingLine)
        guard brief.layout.count > limit else { return brief }
        if let first = Self.firstSentence(of: brief.openingLine), first.count < brief.openingLine.count { brief.openingLine = first }
        if brief.layout.count > limit, let first = Self.firstSentence(of: brief.angle), first.count < brief.angle.count { brief.angle = first }
        while brief.layout.count > limit {
            let cutsLine = brief.openingLine.count >= brief.angle.count
            if cutsLine ? Self.dropLastWord(&brief.openingLine) : Self.dropLastWord(&brief.angle) { continue }
            if !(cutsLine ? Self.dropLastWord(&brief.angle) : Self.dropLastWord(&brief.openingLine)) { break }
        }
        while brief.layout.count > limit, Self.dropLastWord(&brief.subject) {}
        return brief
    }

    // MARK: - What still stands

    /// What of the brief still stands in `text`, the composer's text when it is sent: the creator may have changed the idea, and what they
    /// wrote always wins over what the card said. Nil when the subject is gone (the idea took another direction); the angle or the opening
    /// line are left empty when their words are gone. A part stands when most of its words are still there, in any order: a comma, a
    /// changed word or a moved line keep it, a rewritten one doesn't.
    func standing(in text: String) -> IdeaBrief? {
        let words = Self.tokens(in: text)
        guard Self.stands(subject, in: words, share: Self.subjectShare) else { return nil }
        var kept = self
        if !Self.stands(angle, in: words, share: Self.partShare) { kept.angle = "" }
        if !Self.stands(openingLine, in: words, share: Self.partShare) { kept.openingLine = "" }
        return kept
    }

    /// The share of the headline's words that must still be in the text for the idea to be the same idea.
    static let subjectShare = 0.7
    /// The share of an angle's or an opening line's words that must still be there for it to stand.
    static let partShare = 0.6

    private static func stands(_ part: String, in words: Set<String>, share: Double) -> Bool {
        let needed = tokens(in: part)
        guard !needed.isEmpty else { return false }
        let found = needed.filter { words.contains($0) }.count
        return Double(found) / Double(needed.count) >= share
    }

    /// The words of `text`, folded (case, accents, width) and without punctuation. A script with no spaces between words (Chinese, Japanese,
    /// Thai) is compared by pairs of letters instead: a changed word changes a few of them, a rewritten sentence most.
    static func tokens(in text: String) -> Set<String> {
        let folded = text.folding(options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive], locale: nil)
        let words = folded.split { !$0.isLetter && !$0.isNumber }.map(String.init)
        var tokens = Set<String>()
        for word in words {
            let letters = Array(word)
            if letters.contains(where: isUnspaced), letters.count > 1 {
                for index in 0..<(letters.count - 1) { tokens.insert(String(letters[index...index + 1])) }
            } else if word.count >= 2 || word.first?.isNumber == true {
                tokens.insert(word)
            }
        }
        return tokens
    }

    private static func isUnspaced(_ character: Character) -> Bool {
        character.unicodeScalars.contains { scalar in
            switch scalar.value {
            case 0x0E00...0x0E7F, 0x3040...0x30FF, 0x3400...0x4DBF, 0x4E00...0x9FFF, 0xF900...0xFAFF: true
            default: false
            }
        }
    }

    // MARK: - Words

    private static func trimmed(_ text: String) -> String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// The first sentence of `text`, with its stop; nil when it is one sentence.
    private static func firstSentence(of text: String) -> String? {
        var first: String?
        text.enumerateSubstrings(in: text.startIndex..., options: .bySentences) { sentence, _, _, stop in
            first = sentence.map(trimmed)
            stop = true
        }
        guard let first, !first.isEmpty else { return nil }
        return first
    }

    /// Takes the last word off `text` and ends it with "…"; false when there is nothing left to take (a single word stays whole).
    private static func dropLastWord(_ text: inout String) -> Bool {
        var base = text.hasSuffix("…") ? String(text.dropLast()) : text
        base = trimmed(base)
        var words: [String] = []
        base.enumerateSubstrings(in: base.startIndex..., options: .byWords) { word, _, _, _ in
            if let word { words.append(word) }
        }
        guard words.count > 1, let last = base.range(of: words[words.count - 1], options: .backwards) else { return false }
        var kept = String(base[..<last.lowerBound])
        // No comma, colon or dash left hanging before the ellipsis.
        while let character = kept.last, character.isWhitespace || character.isPunctuation {
            kept.removeLast()
        }
        guard !kept.isEmpty else { return false }
        text = kept + "…"
        return true
    }
}
