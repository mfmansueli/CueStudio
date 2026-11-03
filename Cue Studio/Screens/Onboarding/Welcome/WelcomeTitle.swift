//
//  WelcomeTitle.swift
//  Cue Studio
//

import SwiftUI

/// The promise and the line under it, centred under the C: "A teleprompter made for your creative universe." comes word by word out of the
/// blur (85 ms apart) on lines about as long as each other, a gold light runs over it once it has landed, then the line that says what Cue
/// does (the text follows the voice, captions, posting to every network).
struct WelcomeTitle: View {
    let time: Double

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        let title = String(localized: "A teleprompter made for your creative universe.")
        // By dictionary word in a language written without spaces, so the title breaks into lines instead of running off the screen.
        let words = OnboardingWords.pieces(of: title)
        // The board's 40 pt lines, grown as the title's type grows.
        let lineHeight = InterfaceType.size(40, relativeTo: InterfaceType.style(for: 34), for: dynamicTypeSize, proportion: ScreenProportion.current)
        VStack(alignment: .center, spacing: 14) {
            FlowLayout(spacing: OnboardingWords.isUnspaced(title) ? 0 : 34 * 0.25, lineSpacing: 0, alignment: .center, balanced: true) {
                ForEach(Array(words.enumerated()), id: \.offset) { index, word in
                    let pose = WelcomeScript.titleWord(index).pose(at: time)
                    let glint = WelcomeScript.titleGlint(index, of: words.count).pose(at: time).opacity
                    Text(word)
                        .cueFont(34, weight: .semibold)
                        .tracking(-1.1)
                        .foregroundStyle(Palette.ink.mix(with: Palette.Universe.starGold, by: 0.55 * glint))
                        .shadow(color: Palette.acc.opacity(0.45 * glint), radius: 12)
                        .lineLimit(1)
                        .fixedSize()
                        .frame(height: lineHeight)
                        .opacity(pose.opacity)
                        .offset(y: pose.y)
                        .blur(radius: pose.blur)
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text(title))
            .accessibilityAddTraits(.isHeader)
            let line = WelcomeScript.subtitle.pose(at: time)
            Text("A teleprompter that follows your voice, with captions and posting to all your networks.")
                .cueFont(16)
                .foregroundStyle(Palette.ink2)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .opacity(line.opacity)
                .offset(y: line.y)
        }
    }
}
