//
//  DockChipLight.swift
//  Cue Studio
//

import SwiftUI

/// A light going once round a dock chip as the creator picks on it: a thin rim of `colors` with a soft glow, turning once and fading. On the
/// writer chip, Apple Intelligence's in the dock's own Apple Intelligence colours (`Palette.Scripts.dockGlow`, the `AIGlow` of a dictation) while
/// its symbol bounces, Ultra AI's in Cue's (`Palette.Scripts.ultraGlow`) while its ✦ turns and sends its sparks (`UltraChipSparks`); on the
/// platform chip, the network's colours (`Platform.glow`) while its logo flips. Drawn outside the chip's button (a menu's label is clipped to a
/// rectangle). Each change of `trigger` sends one; at rest nothing shows. Reduce Motion: it doesn't turn, it only fades in and out. Decorative.
struct DockChipLight: View {
    let trigger: Int
    let colors: [Color]

    /// One turn of the light.
    nonisolated static let duration = 0.9

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private struct Light {
        var turn = 0.0
        var strength = 0.0
    }

    var body: some View {
        let colors = colors
        let turn = reduceMotion ? 0.0 : 360
        return Color.clear
            .keyframeAnimator(initialValue: Light(), trigger: trigger) { _, light in
                Self.rim(colors, angle: .degrees(light.turn))
                    .opacity(light.strength)
            } keyframes: { _ in
                KeyframeTrack(\.turn) {
                    LinearKeyframe(0, duration: 0.001)
                    CubicKeyframe(turn, duration: Self.duration)
                }
                KeyframeTrack(\.strength) {
                    LinearKeyframe(1, duration: 0.12)
                    LinearKeyframe(1, duration: Self.duration - 0.45)
                    CubicKeyframe(0, duration: 0.33)
                }
            }
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }

    /// The rim on the chip's edge and its halo: the same colours in wider, fainter strokes spilling a little past the edge without taking
    /// room. Never a blur: a blurred gradient turning is drawn off screen every frame, and it made the chip stutter (29/10/2026).
    private nonisolated static func rim(_ glow: [Color], angle: Angle) -> some View {
        let colors = AngularGradient(colors: glow, center: .center, angle: angle)
        return ZStack {
            Capsule().stroke(colors, lineWidth: 7).opacity(0.14)
            Capsule().stroke(colors, lineWidth: 3.5).opacity(0.3)
            Capsule().strokeBorder(colors, lineWidth: 1.2)
        }
    }
}
