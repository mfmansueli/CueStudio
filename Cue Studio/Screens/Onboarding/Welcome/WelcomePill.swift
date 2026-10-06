//
//  WelcomePill.swift
//  Cue Studio
//

import SwiftUI

/// One of the three words under the title (TELEPROMPTER, AUTO CAPTIONS, ✦ AI SCRIPTS): dim until the star lands on it, then it jumps
/// 12 pt and lights yellow, an oval of light crosses it (clipped by its own radius), a ring opens round it, and it settles back.
struct WelcomePill: View {
    let text: String
    let isAI: Bool
    /// The second the star lands on it.
    let hit: Double
    let time: Double

    var body: some View {
        let pose = WelcomeScript.pill(hit: hit).pose(at: time)
        let lit = pose.blur
        let sweep = WelcomeScript.sweep(hit: hit).pose(at: time)
        let ring = WelcomeScript.wordRing(hit: hit).pose(at: time)
        Text(text)
            .font(.system(size: 10, weight: .semibold, design: .monospaced))
            .tracking(0.8)
            .lineLimit(1)
            .foregroundStyle((isAI ? Palette.aiTextStrong : Palette.ink2).mix(with: Palette.accText, by: lit))
            .padding(.horizontal, 9)
            .frame(height: 26)
            .background {
                Capsule().fill(isAI ? Palette.aiFill : Palette.fill)
                Capsule().fill(Palette.acc.opacity(0.28 * lit))
            }
            .overlay { oval(progress: sweep.scale).opacity(sweep.opacity).clipShape(Capsule()) }
            .shadow(color: Palette.acc.opacity(0.45 * lit), radius: 12 * lit)
            .overlay {
                Circle()
                    .strokeBorder(Palette.acc, lineWidth: 1.2)
                    .frame(width: 28, height: 28)
                    .scaleEffect(ring.scale)
                    .opacity(ring.opacity)
            }
            .scaleEffect(pose.scale)
            .offset(y: pose.y)
            .opacity(pose.opacity)
            .accessibilityLabel(Text(text))
    }

    /// The oval of light: 58% of the pill wide, travelling from before its left edge to past its right.
    private func oval(progress: Double) -> some View {
        GeometryReader { proxy in
            let width = proxy.size.width * 0.58
            Ellipse()
                .fill(RadialGradient(
                    colors: [Palette.starCream.opacity(0.95), Palette.acc.opacity(0.55), Palette.acc.opacity(0)],
                    center: .center, startRadius: 0, endRadius: width / 2
                ))
                .frame(width: width, height: proxy.size.height * 1.6)
                .blur(radius: 2)
                .offset(x: (-1.4 + 4.7 * progress) * width, y: -proxy.size.height * 0.3)
        }
    }
}
