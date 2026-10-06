//
//  WelcomeTitle.swift
//  Cue Studio
//

import SwiftUI

/// The promise and the line under it: "Every creator has a universe to share." comes word by word out of the blur (85 ms apart), then
/// "Script, teleprompter, captions and edit. One place."
struct WelcomeTitle: View {
    let time: Double

    var body: some View {
        let title = String(localized: "Every creator has a universe to share.")
        let words = title.split(separator: " ").map(String.init)
        VStack(alignment: .leading, spacing: 12) {
            FlowLayout(spacing: 34 * 0.26, lineSpacing: 0) {
                ForEach(Array(words.enumerated()), id: \.offset) { index, word in
                    let pose = WelcomeScript.titleWord(index).pose(at: time)
                    Text(word)
                        .font(.system(size: 34, weight: .bold))
                        .tracking(-0.85)
                        .foregroundStyle(Palette.ink)
                        .lineLimit(1)
                        .fixedSize()
                        .frame(height: 40)
                        .opacity(pose.opacity)
                        .offset(y: pose.y)
                        .blur(radius: pose.blur)
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text(title))
            .accessibilityAddTraits(.isHeader)
            let line = WelcomeScript.subtitle.pose(at: time)
            Text("Script, teleprompter, captions and edit. One place.")
                .font(.system(size: 16))
                .foregroundStyle(Palette.ink2)
                .fixedSize(horizontal: false, vertical: true)
                .opacity(line.opacity)
                .offset(y: line.y)
        }
    }
}
