//
//  PersonalizeHero.swift
//  Cue Studio
//

import SwiftUI

/// The top of Settings › Personalize (owner's choice, 21/10/2026): "your Cue" as the creator has made it, all live. The chosen starry sky
/// fills the window; in its middle the light of their universe breathes (its colour, `CoreColor`), and the chosen app icon floats in front
/// of it. Each choice below shows here at once: a new sky fades in, the light turns to its new colour, a new icon comes in on a spring
/// (a little small, past its size, settled). Under them, what is chosen, in words. Reduce Motion: nothing floats or breathes; changes fade.
struct PersonalizeHero: View {
    let icon: AppIconChoice
    let sky: SkyDensity
    let light: CoreColor

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    static let height: CGFloat = 250
    private static let iconSize: CGFloat = 104
    /// Seconds the icon floats up and back, and the light breathes in and out.
    private static let floatPeriod: TimeInterval = 4.2
    private static let breathPeriod: TimeInterval = 3.6

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: Metrics.cardRadius, style: .continuous)
        ZStack {
            SkyMiniature(density: sky)
                .id(sky)
                .transition(.opacity.animation(.easeInOut(duration: 0.6)))
            TimelineView(.animation(paused: reduceMotion)) { context in
                let time = context.date.timeIntervalSinceReferenceDate
                let breath = reduceMotion ? 0.5 : (1 + sin(time / Self.breathPeriod * 2 * .pi)) / 2
                let float = reduceMotion ? 0 : sin(time / Self.floatPeriod * 2 * .pi) * 5
                ZStack {
                    glow(breath: breath)
                    AppIconArt(icon: icon, size: Self.iconSize)
                        .shadow(color: .black.opacity(0.55), radius: 22, y: 14)
                        .id(icon)
                        .transition(iconTransition)
                        .offset(y: -12 + float)
                }
            }
            // White over the sky (its brightest nebula is still dark enough), with a shadow for the stars passing under it.
            Text(summary)
                .font(.footnote.weight(.medium))
                .foregroundStyle(Palette.ink)
                .shadow(color: .black.opacity(0.6), radius: 4)
                .frame(maxHeight: .infinity, alignment: .bottom)
                .padding(.bottom, 16)
                .contentTransition(.opacity)
        }
        .frame(height: Self.height)
        .frame(maxWidth: .infinity)
        .clipShape(shape)
        .overlay(shape.strokeBorder(Palette.glassBorder, lineWidth: 0.5))
        .animation(reduceMotion ? CueMotion.fade : .spring(response: 0.5, dampingFraction: 0.62), value: icon)
        .animation(reduceMotion ? CueMotion.fade : CueMotion.light(duration: 0.8), value: light)
        .animation(CueMotion.fade, value: summary)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(summary))
        .accessibilityIdentifier("personalize.hero")
    }

    /// "Default · Serene sky · Gold light"
    private var summary: String {
        String(localized: "\(icon.title) · \(sky.label) sky · \(light.label) light")
    }

    /// The new icon arrives small and springs past its size; the old one shrinks away under it.
    private var iconTransition: AnyTransition {
        guard !reduceMotion else { return .opacity }
        return .asymmetric(insertion: .scale(scale: 0.6).combined(with: .opacity), removal: .scale(scale: 0.85).combined(with: .opacity))
    }

    /// The universe's light behind the icon, breathing: its glow colour, wide and soft.
    private func glow(breath: Double) -> some View {
        let glow = light.glow
        let color = Color(hex: glow.hex)
        return Circle()
            .fill(RadialGradient(
                colors: [color.opacity(glow.opacity * (0.75 + 0.25 * breath)), color.opacity(0)],
                center: .center, startRadius: 0, endRadius: 115
            ))
            .frame(width: 230, height: 230)
            .scaleEffect(0.94 + 0.12 * breath)
            .offset(y: -12)
    }
}
