//
//  OnboardingTopicChip.swift
//  Cue Studio
//

import SwiftUI

/// A topic on 1.2: a quiet glass chip, 32 pt tall, 12.5 pt semibold, with an empty bar before its name (3 × 14 pt, never a dot). Picked,
/// the bar fills with its world's colour (popping in with a spring), the chip takes a tint and an edge of that colour and its name turns
/// bright; an oval of the colour crosses it once, clipped by its own radius. The bar is there picked or not, so a pick never moves the
/// chips around it.
struct OnboardingTopicChip: View {
    let title: String
    /// The colour of the world it became, when picked.
    let color: Color?
    /// When it was picked, for the light that crosses it.
    let tap: Date?
    /// Three topics are picked and this is not one of them: it drops to 40% (a tap does nothing, 09 §14).
    var isDimmed = false
    let identifier: String
    let action: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var isPicked: Bool { color != nil }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 7) {
                bar
                Text(title)
            }
            // 32 pt tall, 12.5 pt (09 §14b); the 44 pt target is the chip with 6 pt above and below, which the rows overlap.
            .cueFont(12.5, weight: .semibold)
            .foregroundStyle(isPicked ? Palette.ink : Palette.ink2)
            .padding(.leading, 10)
            .padding(.trailing, 12)
            .frame(height: 32)
            .background { Capsule().fill(Palette.fill) }
            .background { Capsule().fill((color ?? .clear).opacity(0.22)) }
            .overlay { Capsule().strokeBorder(color.map { $0.opacity(0.7) } ?? Palette.glassBorder, lineWidth: isPicked ? 1 : 0.75) }
            .overlay { light }
            .shadow(color: (color ?? .clear).opacity(0.35), radius: 10)
            .opacity(isDimmed ? 0.4 : 1)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.22).delay(0.02), value: isPicked)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.2), value: isDimmed)
            .padding(.vertical, 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(title))
        .accessibilityAddTraits(isPicked ? [.isButton, .isSelected] : .isButton)
        .accessibilityIdentifier(identifier)
    }

    /// The bar: an outline waiting for a world, filled with its colour once picked.
    private var bar: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 1.5).strokeBorder(Palette.ink3, lineWidth: 1)
            RoundedRectangle(cornerRadius: 1.5)
                .fill(color ?? .clear)
                .shadow(color: (color ?? .clear).opacity(0.7), radius: 6)
                .scaleEffect(y: isPicked ? 1 : 0)
                .animation(reduceMotion ? nil : .timingCurve(0.3, 1.5, 0.5, 1, duration: 0.4).delay(0.05), value: isPicked)
        }
        .frame(width: 3, height: 14)
    }

    /// The oval of the topic's colour crossing the chip (0.12–0.64 s after the tap).
    @ViewBuilder
    private var light: some View {
        if let color, let tap, !reduceMotion {
            TimelineView(.animation(paused: Date.now.timeIntervalSince(tap) > 0.7)) { context in
                let pose = TopicBirth.sweep.pose(at: context.date.timeIntervalSince(tap))
                GeometryReader { proxy in
                    let width = proxy.size.width * 0.55
                    Ellipse()
                        .fill(RadialGradient(
                            colors: [color.opacity(0.6), color.opacity(0.25), color.opacity(0)], center: .center, startRadius: 0, endRadius: width / 2
                        ))
                        .frame(width: width, height: proxy.size.height * 1.6)
                        .blur(radius: 3)
                        .offset(x: (-1.2 + 4.5 * pose.scale) * width, y: -proxy.size.height * 0.3)
                }
                .opacity(pose.opacity)
                .clipShape(Capsule())
                .allowsHitTesting(false)
            }
        }
    }
}
