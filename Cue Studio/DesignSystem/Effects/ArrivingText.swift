//
//  ArrivingText.swift
//  Cue Studio
//

import SwiftUI

/// The words of a script as the AI writes them into the page (v30 · 4.1, `sc1…`): each word comes in from blur 7 pt and 5 pt below in 0.3 s
/// (`(.16, 1, .3, 1)`), flashing a 14 pt violet glow (`#C4B8FF` at 95%) that is gone 0.8 s later, 0.17 s after the word before it. A 2 pt violet
/// caret blinks after the last word (1 s, on for the first half). It grows as `text` grows: the words already on the page stay, only the new ones
/// arrive. Under Reduce Motion the new words fade in together and the caret stays lit. Never for what the creator types.
///
/// The words can come styled (`AttributedString`): a script's page hands in its text as its editor draws it, cues as chips (`TextChip`, drawn
/// by `ArrivalRenderer` behind their words), so the words arrive looking the way they will stay. A chip arrives whole, as one word, however
/// many spaces its words have ("[look at camera]").
struct ArrivingText: View {
    let text: AttributedString
    var size: CGFloat = 19
    var lineSpacing: CGFloat = 6
    var color: Color = Palette.ink

    init(text: String, size: CGFloat = 19, lineSpacing: CGFloat = 6, color: Color = Palette.ink) {
        self.init(styled: AttributedString(text), size: size, lineSpacing: lineSpacing, color: color)
    }

    /// Words with their own fonts and colours where they have them; the rest takes `size` and `color`.
    init(styled text: AttributedString, size: CGFloat = 19, lineSpacing: CGFloat = 6, color: Color = Palette.ink) {
        self.text = text
        self.size = size
        self.lineSpacing = lineSpacing
        self.color = color
    }

    /// Seconds between one word's arrival and the next.
    static let stagger = 0.17
    /// Seconds a word takes to arrive, and until its glow is gone.
    static let arrive = 0.3
    static let glowFade = 0.8
    /// Seconds from the last words handed in until every one of them has arrived sharp (they run at most half a second behind, a few apart,
    /// and take `arrive`); their glow is still fading then. What shows the words waits this long before it hands over to something else.
    static let settleTime = 1.3

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var clock = ArrivalClock()

    var body: some View {
        let words = Self.tokens(of: text)
        TimelineView(.animation(minimumInterval: 1.0 / 60, paused: false)) { context in
            let now = context.date.timeIntervalSinceReferenceDate
            Self.marked(words)
                .font(.system(size: size))
                .lineSpacing(lineSpacing)
                .foregroundStyle(color)
                .textRenderer(
                    ArrivalRenderer(
                        now: now,
                        arrivals: clock.arrivals(for: words.count, now: now),
                        reduceMotion: reduceMotion,
                        chipMetrics: TextChipMetrics(textSize: size)
                    )
                )
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(String(text.characters)))
    }

    /// The styled text cut the way `tokens(of:)` cuts its characters, each piece keeping its style, except that a chip is never cut:
    /// the words of "[look at camera]" stay one piece.
    static func tokens(of text: AttributedString) -> [AttributedString] {
        let characters = text.characters
        var chips: [Range<Int>] = []
        for (chip, range) in text.runs[TextChipAttribute.self] where chip != nil {
            let lower = characters.distance(from: characters.startIndex, to: range.lowerBound)
            chips.append(lower..<(lower + characters.distance(from: range.lowerBound, to: range.upperBound)))
        }
        var lengths: [Int] = []
        var offset = 0
        for token in tokens(of: String(characters)) {
            if !lengths.isEmpty, chips.contains(where: { $0.lowerBound < offset && offset < $0.upperBound }) {
                lengths[lengths.count - 1] += token.count
            } else {
                lengths.append(token.count)
            }
            offset += token.count
        }
        var start = characters.startIndex
        return lengths.map { length in
            let end = characters.index(start, offsetBy: length)
            defer { start = end }
            return AttributedString(text[start..<end])
        }
    }

    /// Each word with the space or line break that follows it, so the paragraphs stay as written.
    static func tokens(of text: String) -> [String] {
        var tokens: [String] = []
        var current = ""
        var inSpace = false
        for character in text {
            let isSpace = character.isWhitespace
            if inSpace, !isSpace {
                tokens.append(current)
                current = ""
            }
            inSpace = isSpace
            current.append(character)
        }
        if !current.isEmpty { tokens.append(current) }
        return tokens
    }

    /// The tokens as one `Text`, each marked with its place (the renderer draws the caret after the last word to have arrived), and the
    /// runs of a chip marked with it (the renderer draws the chip behind them).
    static func marked(_ words: [AttributedString]) -> Text {
        Text.joined(words.enumerated().map { piece($0.element).customAttribute(ArrivalIndex(index: $0.offset)) })
    }

    /// A word as `Text`, a chip's runs marked with it. A chip's spaces are drawn as non-breaking ones (one for one, so nothing moves):
    /// `Text` can't be told where not to wrap, and the editor never splits a chip across two lines either.
    private static func piece(_ word: AttributedString) -> Text {
        let runs = word.runs[TextChipAttribute.self]
        guard runs.contains(where: { $0.0 != nil }) else { return Text(word) }
        return Text.joined(runs.map { chip, range in
            guard let chip else { return Text(AttributedString(word[range])) }
            var run = AttributedString(word[range])
            while let space = run.characters.firstIndex(of: " ") {
                run.characters.replaceSubrange(space...space, with: "\u{00A0}")
            }
            return Text(run).customAttribute(chip)
        })
    }
}
