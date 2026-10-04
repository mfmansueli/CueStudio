//
//  WordsFromLight.swift
//  Cue Studio
//

import SwiftUI

/// The words of what the AI writes, arriving one by one: each goes from invisible, blurred and 6 pt low
/// to sharp in 0.3 s, carrying a violet glow that fades over 0.9 s, 0.16 s after the word before it. It
/// is only for text arriving from the model: never animate what the creator is typing. Under Reduce
/// Motion the words simply fade in together.
struct WordsFromLight: View {
    let text: String
    var font: Font = .system(size: 21, weight: .regular)
    var color: Color = Palette.aiTextStrong
    /// Seconds between the words.
    var stagger = CueMotion.Duration.wordStagger
    /// Change to play again.
    var trigger = 0

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var elapsed = 0.0

    private var words: [Substring] { text.split(separator: " ", omittingEmptySubsequences: true) }

    /// Seconds until every word has arrived (and its glow gone).
    var totalDuration: Double {
        Double(max(0, words.count - 1)) * stagger + CueMotion.Duration.wordFromLight + 0.9
    }

    var body: some View {
        Self.marked(words: words)
            .font(font)
            .foregroundStyle(color)
            .textRenderer(WordsRenderer(elapsed: elapsed, stagger: stagger, reduceMotion: reduceMotion))
            .accessibilityLabel(Text(text))
            .task(id: "\(text)\(trigger)") {
                elapsed = 0
                guard !reduceMotion else { elapsed = totalDuration; return }
                withAnimation(.linear(duration: totalDuration)) { elapsed = totalDuration }
            }
    }

    /// The text with each word marked by its index, which the renderer reads.
    static func marked(words: [Substring]) -> Text {
        words.enumerated().reduce(Text(verbatim: "")) { text, item in
            let word = Text(verbatim: item.offset == 0 ? String(item.element) : " " + item.element).customAttribute(WordIndexAttribute(index: item.offset))
            return Text("\(text)\(word)")
        }
    }
}

/// Marks a run of text with the index of the word it holds.
private struct WordIndexAttribute: TextAttribute {
    var index: Int
}

private struct WordsRenderer: TextRenderer {
    var elapsed: Double
    var stagger: Double
    var reduceMotion: Bool

    var animatableData: Double {
        get { elapsed }
        set { elapsed = newValue }
    }

    func draw(layout: Text.Layout, in context: inout GraphicsContext) {
        for line in layout {
            for run in line {
                let index = run[WordIndexAttribute.self]?.index ?? 0
                let age = elapsed - Double(index) * stagger
                let progress = reduceMotion ? min(1, max(0, elapsed / 0.4)) : min(1, max(0, age / CueMotion.Duration.wordFromLight))
                let glow = reduceMotion ? 0 : max(0, 1 - max(0, age - CueMotion.Duration.wordFromLight) / 0.9)
                var copy = context
                copy.opacity = progress
                if !reduceMotion {
                    copy.translateBy(x: 0, y: 6 * (1 - progress))
                    copy.addFilter(.blur(radius: 8 * (1 - progress)))
                }
                if glow > 0, progress > 0 {
                    var glowing = copy
                    glowing.addFilter(.shadow(color: Palette.aiText.opacity(0.9 * glow), radius: 6))
                    glowing.draw(run)
                } else {
                    copy.draw(run)
                }
            }
        }
    }
}
