//
//  WelcomeWordmark.swift
//  Cue Studio
//

import SwiftUI

/// "CUE STUDIO" under the C (SF Mono 13 pt, 600, lavender): the letters leave from the middle outward, stretched across and blurred,
/// and settle while the tracking closes from 1 em to 0.34 em; a yellow glint runs over them once.
struct WelcomeWordmark: View {
    let time: Double

    private static let fontSize: CGFloat = 13

    var body: some View {
        let letters = WelcomeScript.letters
        let tracking = WelcomeScript.tracking.pose(at: time).scale * Self.fontSize
        HStack(spacing: tracking) {
            ForEach(Array(letters.enumerated()), id: \.offset) { index, letter in
                if index == 3 { Color.clear.frame(width: max(0, Self.fontSize * 0.5 - tracking), height: 1) }
                glyph(letter)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("CUE STUDIO"))
    }

    private func glyph(_ letter: WelcomeScript.Letter) -> some View {
        let pose = letter.track.pose(at: time)
        let glint = letter.glow.pose(at: time).opacity
        return Text(String(letter.character))
            .font(.system(size: Self.fontSize, weight: .semibold, design: .monospaced))
            .foregroundStyle(Palette.aiTextStrong.mix(with: Palette.Universe.starGold, by: glint))
            .shadow(color: Palette.acc.opacity(0.85 * glint), radius: 10)
            .scaleEffect(x: pose.scaleX, y: pose.scaleY)
            .blur(radius: pose.blur)
            .opacity(pose.opacity)
    }
}
