//
//  WelcomePill.swift
//  Cue Studio
//

import SwiftUI

/// One of the three words under the title (FOLLOWS YOUR VOICE, AUTO CAPTIONS, ✦ AI SCRIPTS): a quiet glass pill with a mark before its
/// words, a dot (the ✦ for the AI one). Dim until the star skims the mark; then the mark turns gold and swells, a ring opens from it, the
/// pill's edge glows gold and it lifts a little; it settles lit, the mark gold, a faint gold edge. "Get started" is
/// the only solid yellow on the screen.
struct WelcomePill: View {
    let text: String
    let isAI: Bool
    /// The second the star lands on it.
    let hit: Double
    let time: Double
    /// The coordinate space `onMark` reports in.
    let space: String
    /// Where the mark is, so the star lands on it.
    let onMark: (CGPoint) -> Void

    private static let sparkle = "✦"

    var body: some View {
        let pose = WelcomeScript.pill(hit: hit).pose(at: time)
        let lit = pose.blur
        let ring = WelcomeScript.wordRing(hit: hit).pose(at: time)
        // 1 when the star lands, 0.3 once settled: how much of the flare is left (1 → 0).
        let glow = WelcomeScript.pillGlow(hit: hit).pose(at: time).opacity
        let flare = lit * max(0, (glow - 0.3) / 0.7)
        HStack(spacing: 6) {
            mark(lit: lit, flare: flare)
                .overlay {
                    Circle()
                        .strokeBorder(Palette.acc, lineWidth: 1)
                        .frame(width: 12, height: 12)
                        .scaleEffect(ring.scale * 1.4)
                        .opacity(ring.opacity)
                }
                .onGeometryChange(for: CGPoint.self) { proxy in
                    let frame = proxy.frame(in: .named(space))
                    return CGPoint(x: frame.midX, y: frame.midY)
                } action: { onMark($0) }
            Text(words)
                .monoFont(size: 10, weight: .semibold)
                .interfaceTracking(0.8)
                .lineLimit(1)
                .foregroundStyle(isAI ? Palette.aiTextStrong : Palette.ink2.mix(with: Palette.ink, by: lit))
        }
        .padding(.leading, 10)
        .padding(.trailing, 11)
        .padding(.vertical, 5)
        .frame(minHeight: 28)
        .background { Capsule().fill(isAI ? Palette.aiFill : Palette.fill) }
        .overlay {
            Capsule().strokeBorder(Palette.glassBorder.mix(with: Palette.acc, by: 0.3 * lit + 0.6 * flare), lineWidth: 0.75)
        }
        .shadow(color: Palette.acc.opacity(0.35 * flare), radius: 10 * flare)
        .scaleEffect(pose.scale)
        .offset(y: pose.y)
        .opacity(pose.opacity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(text))
    }

    /// The words without the ✦, which becomes the AI pill's mark.
    private var words: String {
        guard isAI, text.hasPrefix(Self.sparkle) else { return text }
        return String(text.dropFirst()).trimmingCharacters(in: .whitespaces)
    }

    /// The dot (the ✦ for the AI pill): dim, gold once the star lands on it, swollen at the landing.
    private func mark(lit: Double, flare: Double) -> some View {
        let color = Palette.ink3.mix(with: Palette.acc, by: lit)
        return Group {
            if isAI {
                Text(verbatim: Self.sparkle)
                    .font(.fixed(10, weight: .bold))
                    .foregroundStyle(Palette.aiTextStrong.mix(with: Palette.acc, by: lit))
            } else {
                Circle().fill(color).frame(width: 5, height: 5)
            }
        }
        .frame(width: 10, height: 10)
        .shadow(color: Palette.acc.opacity(0.9 * lit), radius: 3 + 5 * flare)
        .scaleEffect(1 + 0.8 * flare)
    }
}
