//
//  WelcomeTitle.swift
//  Cue Studio
//

import SwiftUI

/// The promise and the line under it: "A teleprompter made for your creative universe." comes word by word out of the blur (85 ms apart), then
/// the line that says what Cue does, from the script to sharing.
struct WelcomeTitle: View {
    let time: Double

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        let title = String(localized: "A teleprompter made for your creative universe.")
        // By dictionary word in a language written without spaces, so the title breaks into lines instead of running off the screen.
        let words = OnboardingWords.pieces(of: title)
        // The board's 40 pt lines, grown as the title's type grows.
        let lineHeight = InterfaceType.size(40, relativeTo: InterfaceType.style(for: 34), for: dynamicTypeSize, proportion: ScreenProportion.current)
        VStack(alignment: .leading, spacing: 12) {
            FlowLayout(spacing: OnboardingWords.isUnspaced(title) ? 0 : 34 * 0.26, lineSpacing: 0) {
                ForEach(Array(words.enumerated()), id: \.offset) { index, word in
                    let pose = WelcomeScript.titleWord(index).pose(at: time)
                    Text(word)
                        .cueFont(34, weight: .bold)
                        .tracking(-0.85)
                        .foregroundStyle(Palette.ink)
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
            Text("Write your script, read it while you look at the camera, and record. Then add captions, edit, and share.")
                .cueFont(16)
                .foregroundStyle(Palette.ink2)
                .fixedSize(horizontal: false, vertical: true)
                .opacity(line.opacity)
                .offset(y: line.y)
        }
    }
}
