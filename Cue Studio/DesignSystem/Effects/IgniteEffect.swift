//
//  IgniteEffect.swift
//  Cue Studio
//

import SwiftUI

/// Something important started: a star lights. The core goes 0 → 1.8 → 1 with an overshoot, two waves of
/// light grow from it (the second 0.18 s later) and a cross flare opens and settles. Change `trigger` to
/// play it. Under Reduce Motion the star only fades in.
struct IgniteEffect: View {
    var trigger: Int
    var color: Color = Palette.acc
    var diameter: CGFloat = 14

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private struct Frame {
        var core = 0.0
        var wave = 0.0
        var secondWave = 0.0
        var flare = 0.0
    }

    var body: some View {
        if reduceMotion {
            Circle()
                .fill(color)
                .frame(width: diameter, height: diameter)
                .shadow(color: color.opacity(0.7), radius: 8)
                .opacity(trigger > 0 ? 1 : 0)
                .animation(CueMotion.fade, value: trigger)
                .accessibilityHidden(true)
        } else {
            KeyframeAnimator(initialValue: Frame(), trigger: trigger) { frame in
                ZStack {
                    wave(progress: frame.wave)
                    wave(progress: frame.secondWave)
                    cross(opening: frame.flare)
                    Circle()
                        .fill(color)
                        .frame(width: diameter, height: diameter)
                        .scaleEffect(frame.core)
                        .shadow(color: color.opacity(0.8), radius: 10 * frame.core)
                }
                .frame(width: diameter, height: diameter)
            } keyframes: { _ in
                KeyframeTrack(\.core) {
                    LinearKeyframe(0, duration: 0.01)
                    CubicKeyframe(1.8, duration: 0.3)
                    CubicKeyframe(1, duration: 0.35)
                }
                KeyframeTrack(\.wave) {
                    LinearKeyframe(0, duration: 0.01)
                    CubicKeyframe(1, duration: CueMotion.Duration.igniteWaves)
                }
                KeyframeTrack(\.secondWave) {
                    LinearKeyframe(0, duration: 0.18)
                    CubicKeyframe(1, duration: CueMotion.Duration.igniteWaves)
                }
                KeyframeTrack(\.flare) {
                    LinearKeyframe(0, duration: 0.01)
                    CubicKeyframe(1, duration: 0.18)
                    CubicKeyframe(0.3, duration: 0.72)
                }
            }
            .accessibilityHidden(true)
        }
    }

    /// A ring of light growing from 0.4× to 6.5× the star and fading out.
    private func wave(progress: Double) -> some View {
        Circle()
            .strokeBorder(color.opacity(0.7 * (1 - progress)), lineWidth: 1.5)
            .frame(width: diameter, height: diameter)
            .scaleEffect(0.4 + 6.1 * progress)
            .opacity(progress > 0 ? 1 : 0)
    }

    /// The flare: two thin lines crossing at the star.
    private func cross(opening: Double) -> some View {
        ZStack {
            Capsule().fill(LinearGradient(colors: [color.opacity(0), .white, color.opacity(0)], startPoint: .leading, endPoint: .trailing))
                .frame(width: diameter * 4.5 * opening, height: 1)
            Capsule().fill(LinearGradient(colors: [color.opacity(0), .white, color.opacity(0)], startPoint: .top, endPoint: .bottom))
                .frame(width: 1, height: diameter * 4.5 * opening)
        }
        .opacity(opening)
    }
}

#if DEBUG
#Preview {
    @Previewable @State var count = 0
    IgniteEffect(trigger: count)
        .frame(width: 160, height: 160)
        .background(Palette.bg)
        .onTapGesture { count += 1 }
}
#endif
