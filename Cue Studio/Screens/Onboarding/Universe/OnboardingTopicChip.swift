//
//  OnboardingTopicChip.swift
//  Cue Studio
//

import SwiftUI

/// A topic on 1.2: 38 pt tall, 14.5 pt semibold. Picked, it turns white and takes a vertical bar of its world's colour (3 × 14 pt, never a dot)
/// that pops in with a spring; an oval of light crosses it, clipped by the chip's own radius.
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
            HStack(spacing: 6) {
                if let color {
                    RoundedRectangle(cornerRadius: 1.5)
                        .fill(color)
                        .frame(width: 3, height: 14)
                        .shadow(color: color.opacity(0.6), radius: 8)
                        .transition(.scale.animation(reduceMotion ? nil : .timingCurve(0.3, 1.5, 0.5, 1, duration: 0.25).delay(0.05)))
                }
                Text(title)
            }
            // 32 pt tall, 12.5 pt (09 §14b); the 44 pt target is the chip with 6 pt above and below, which the rows overlap.
            .font(.system(size: 12.5, weight: .semibold))
            .foregroundStyle(isPicked ? Palette.chipOnInk : Palette.ink2)
            .padding(.leading, isPicked ? 8 : 11)
            .padding(.trailing, isPicked ? 10 : 11)
            .frame(height: 32)
            .background(isPicked ? Palette.chipOn : Palette.fill, in: Capsule())
            .overlay { light }
            .opacity(isDimmed ? 0.4 : 1)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.16).delay(0.02), value: isPicked)
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
                            colors: [color.opacity(0.85), color.opacity(0.4), color.opacity(0)], center: .center, startRadius: 0, endRadius: width / 2
                        ))
                        .frame(width: width, height: proxy.size.height * 1.6)
                        .blur(radius: 2)
                        .offset(x: (-1.2 + 4.5 * pose.scale) * width, y: -proxy.size.height * 0.3)
                }
                .opacity(pose.opacity)
                .clipShape(Capsule())
                .allowsHitTesting(false)
            }
        }
    }
}
