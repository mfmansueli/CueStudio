//
//  ArrivingText.swift
//  Cue Studio
//

import SwiftUI

/// The words of a script as the AI writes them into the page (v30 · 4.1, `sc1…`): each word comes in from blur 7 pt and 5 pt below in 0.3 s
/// (`(.16, 1, .3, 1)`), flashing a 14 pt violet glow (`#C4B8FF` at 95%) that is gone 0.8 s later, 0.17 s after the word before it. A 2 pt violet
/// caret blinks after the last word (1 s, on for the first half). It grows as `text` grows: the words already on the page stay, only the new ones
/// arrive. Under Reduce Motion the new words fade in together and the caret stays lit. Never for what the creator types.
struct ArrivingText: View {
    let text: String
    var size: CGFloat = 19
    var lineSpacing: CGFloat = 6
    var color: Color = Palette.ink

    /// Seconds between one word's arrival and the next.
    static let stagger = 0.17
    /// Seconds a word takes to arrive, and until its glow is gone.
    static let arrive = 0.3
    static let glowFade = 0.8

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
                .textRenderer(ArrivalRenderer(now: now, arrivals: clock.arrivals(for: words.count, now: now), reduceMotion: reduceMotion))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(text))
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

    /// The tokens as one `Text`, each marked with its place (the renderer draws the caret after the last word to have arrived).
    static func marked(_ words: [String]) -> Text {
        words.enumerated().reduce(Text(verbatim: "")) { text, item in
            Text("\(text)\(Text(verbatim: item.element).customAttribute(ArrivalIndex(index: item.offset)))")
        }
    }
}

/// When each word came on to the page: a word seen for the first time is given the next free slot after the one before it.
@MainActor
private final class ArrivalClock {
    private var times: [Double] = []

    /// New words are given slots 0.17 s apart (closer when many come at once), but never further than half a second from now, so the page
    /// never trails the model by more than about a second however long the script is.
    func arrivals(for count: Int, now: TimeInterval) -> [Double] {
        if count > times.count {
            let added = count - times.count
            let start = times.isEmpty ? now : min(max(now, (times.last ?? now) + ArrivingText.stagger), now + 0.5)
            let spacing = min(ArrivingText.stagger, 0.7 / Double(added))
            for offset in 0..<added { times.append(start + Double(offset) * spacing) }
        }
        if count < times.count { times.removeLast(times.count - count) }
        return times
    }
}

struct ArrivalIndex: TextAttribute {
    var index: Int
}

private struct ArrivalRenderer: TextRenderer {
    var now: Double
    var arrivals: [Double]
    var reduceMotion: Bool

    func draw(layout: Text.Layout, in context: inout GraphicsContext) {
        // The caret follows the last word that has started to arrive, and sits at the start of the page until one does.
        var caretAt: CGRect?
        for line in layout {
            for run in line {
                guard let mark = run[ArrivalIndex.self] else { context.draw(run); continue }
                let age = mark.index < arrivals.count ? now - arrivals[mark.index] : 0
                let progress = reduceMotion ? min(1, max(0, age / 0.2)) : Self.ease(min(1, max(0, age / ArrivingText.arrive)))
                let glow = reduceMotion ? 0 : max(0, 1 - max(0, age - ArrivingText.arrive) / ArrivingText.glowFade)
                let bounds = run.typographicBounds.rect
                if caretAt == nil { caretAt = CGRect(x: bounds.minX, y: bounds.minY, width: 0, height: bounds.height) }
                if progress > 0 { caretAt = CGRect(x: bounds.maxX, y: bounds.minY, width: 0, height: bounds.height) }
                var copy = context
                copy.opacity = progress
                if !reduceMotion {
                    copy.translateBy(x: 0, y: 5 * (1 - progress))
                    copy.addFilter(.blur(radius: 7 * (1 - progress)))
                }
                if glow > 0, progress > 0 {
                    copy.addFilter(.shadow(color: Color(hex: 0xC4B8FF, opacity: 0.95 * glow), radius: 14 * glow))
                }
                copy.draw(run)
            }
        }
        guard let caretAt else { return }
        // `blink 1s`: lit for the first half of every second, in the AI's violet.
        let lit = reduceMotion || now.truncatingRemainder(dividingBy: 1) < 0.5
        var caret = context
        caret.opacity = lit ? 1 : 0
        caret.addFilter(.shadow(color: Palette.aiText.opacity(0.9), radius: 6))
        caret.fill(Path(CGRect(x: caretAt.minX + 1, y: caretAt.minY + 2, width: 2, height: caretAt.height - 4)), with: .color(Color(hex: 0xB4A7FF)))
    }

    /// `cubic-bezier(.16, 1, .3, 1)`, close enough as an ease-out.
    private static func ease(_ t: Double) -> Double {
        1 - pow(1 - t, 3.4)
    }
}
