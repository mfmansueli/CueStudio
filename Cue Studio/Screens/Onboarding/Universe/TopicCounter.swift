//
//  TopicCounter.swift
//  Cue Studio
//

import SwiftUI

/// "2 OF 3 · ADD ONE MORE OR CONTINUE" with three bars before it (09 §14): one 3 × 16 pt bar per topic that can be picked, empty as a 1 pt
/// outline at 40%, filled in the colour of the world it became. A new bar pops when its topic is picked (0 → 1.25 → 1, 0.45 s,
/// `cubic-bezier(.3,1.5,.5,1)`). At three the line goes yellow ("TAP ONE TO SWAP").
struct TopicCounter: View {
    /// The colour of each picked topic's world, in the order picked.
    let colors: [Color]

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var text: String {
        switch colors.count {
        case 0: String(localized: "PICK 1 TO 3 TOPICS")
        case 1: String(localized: "\(colors.count) OF \(OnboardingTopic.limit) · ADD MORE OR CONTINUE")
        case OnboardingTopic.limit: String(localized: "\(colors.count) OF \(OnboardingTopic.limit) · TAP ONE TO SWAP")
        default: String(localized: "\(colors.count) OF \(OnboardingTopic.limit) · ADD ONE MORE OR CONTINUE")
        }
    }

    private var isFull: Bool { colors.count >= OnboardingTopic.limit }

    var body: some View {
        HStack(spacing: 9) {
            HStack(spacing: 3) {
                ForEach(0..<OnboardingTopic.limit, id: \.self) { index in bar(index) }
            }
            Text(text)
                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                .tracking(1.2)
                .foregroundStyle(isFull ? Palette.starGold : Color.white.opacity(0.82))
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
                .id(text)
                .transition(.opacity)
        }
        .animation(reduceMotion ? nil : .easeOut(duration: 0.2), value: text)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(text))
        .accessibilityIdentifier("onboarding.topicCounter")
    }

    private func bar(_ index: Int) -> some View {
        let color = colors.indices.contains(index) ? colors[index] : nil
        return ZStack {
            RoundedRectangle(cornerRadius: 1.5).strokeBorder(Color.white.opacity(0.4), lineWidth: 1)
            RoundedRectangle(cornerRadius: 1.5)
                .fill(color ?? .clear)
                .shadow(color: (color ?? .clear).opacity(0.6), radius: 8)
                .scaleEffect(y: color == nil ? 0 : 1)
                .animation(reduceMotion ? nil : .timingCurve(0.3, 1.5, 0.5, 1, duration: 0.45), value: color != nil)
        }
        .frame(width: 3, height: 16)
    }
}

#if DEBUG
#Preview {
    VStack(alignment: .leading, spacing: 12) {
        TopicCounter(colors: [])
        TopicCounter(colors: [Palette.World.warm, Palette.World.mint])
        TopicCounter(colors: [Palette.World.warm, Palette.World.mint, Palette.World.pink])
    }
    .padding()
    .background(Palette.flightNight)
}
#endif
