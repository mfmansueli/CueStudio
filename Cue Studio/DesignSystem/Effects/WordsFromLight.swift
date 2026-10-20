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
    /// The violet glow each word carries as it arrives (the AI's own words); ours fade in plainly.
    var glows = true
    /// The first text plays too. False: the first one is simply there, and only the texts that come after it arrive (a suggestion that was
    /// already there when the screen opened isn't news).
    var playsFirst = true

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var elapsed = 0.0
    /// The text and trigger last played: seen again (the view came back on screen), it is simply there.
    @State private var played: String?

    private var words: [Substring] { text.split(separator: " ", omittingEmptySubsequences: true) }

    /// Seconds until every word has arrived (and its glow gone).
    var totalDuration: Double {
        Double(max(0, words.count - 1)) * stagger + CueMotion.Duration.wordFromLight + 0.9
    }

    var body: some View {
        Self.marked(words: words)
            .font(font)
            .foregroundStyle(color)
            .textRenderer(WordsRenderer(elapsed: elapsed, stagger: stagger, reduceMotion: reduceMotion, glows: glows))
            .accessibilityLabel(Text(text))
            .task(id: "\(text)\(trigger)") {
                let key = "\(text)\(trigger)"
                let isNews = played != key && (played != nil || playsFirst)
                played = key
                elapsed = 0
                guard isNews, !reduceMotion else { elapsed = totalDuration; return }
                withAnimation(.linear(duration: totalDuration)) { elapsed = totalDuration }
            }
    }

    /// The text with each word marked by its index, which the renderer reads.
    static func marked(words: [Substring]) -> Text {
        Text.joined(words.enumerated().map { index, word in
            Text(verbatim: index == 0 ? String(word) : " " + word).customAttribute(WordIndexAttribute(index: index))
        })
    }
}
