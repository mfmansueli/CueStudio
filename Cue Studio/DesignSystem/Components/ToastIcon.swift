//
//  ToastIcon.swift
//  Cue Studio
//

import SwiftUI

/// A toast's round icon (`ToastKind`) and the gesture it makes once, as the toast arrives: the disc grows in, then the ✓ draws
/// itself (the system's Draw On), the ★ turns in and settles, the ! shakes its head. Work under way shows a turning ring; when the
/// work ends, the icon of what came of it arrives in its place the same way (`ToastView` gives each kind its own icon). Under
/// Reduce Motion the icons arrive still; the ring keeps turning, because it says the work goes on.
struct ToastIcon: View {
    let kind: ToastKind
    @ScaledMetric(relativeTo: .subheadline) private var size: CGFloat = 26
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// The disc has grown in.
    @State private var arrived = false
    /// The ✓ is drawn.
    @State private var drawn = false
    /// The ★ and the ! have started their gesture.
    @State private var gestured = false

    var body: some View {
        ZStack {
            if kind == .working {
                ring
            } else {
                Circle().fill(fill)
                glyph
            }
        }
        .frame(width: size, height: size)
        .scaleEffect(arrived || reduceMotion ? 1 : 0.5)
        .opacity(arrived || reduceMotion ? 1 : 0)
        .accessibilityHidden(true)
        .task { await arrive() }
    }

    private var fill: Color {
        switch kind {
        case .done: Palette.Toast.done
        case .cue: Palette.Toast.cue
        case .problem: Palette.Toast.problem
        case .working: .clear
        }
    }

    @ViewBuilder private var glyph: some View {
        switch kind {
        case .done:
            if drawn || reduceMotion {
                Image(systemName: "checkmark")
                    .font(.system(size: size * 0.5, weight: .bold))
                    .foregroundStyle(Palette.Toast.glyph)
                    .transition(.symbolEffect(.drawOn))
            }
        case .cue:
            Image(systemName: "star.fill")
                .font(.system(size: size * 0.52, weight: .bold))
                .foregroundStyle(Palette.Toast.glyph)
                .keyframeAnimator(initialValue: ToastGlyphMotion(), trigger: gestured) { content, motion in
                    content.scaleEffect(motion.scale).rotationEffect(.degrees(motion.angle)).opacity(motion.opacity)
                } keyframes: { _ in
                    KeyframeTrack(\.scale) {
                        MoveKeyframe(0.4)
                        CubicKeyframe(1.18, duration: 0.27)
                        CubicKeyframe(1, duration: 0.18)
                    }
                    KeyframeTrack(\.angle) {
                        MoveKeyframe(-40)
                        CubicKeyframe(8, duration: 0.27)
                        CubicKeyframe(0, duration: 0.18)
                    }
                    KeyframeTrack(\.opacity) {
                        MoveKeyframe(0)
                        LinearKeyframe(1, duration: 0.16)
                    }
                }
                // Hidden until it turns in, so it never shows whole before its gesture.
                .opacity(gestured || reduceMotion ? 1 : 0)
        case .problem:
            Image(systemName: "exclamationmark")
                .font(.system(size: size * 0.55, weight: .heavy))
                .foregroundStyle(Palette.Toast.glyph)
                .keyframeAnimator(initialValue: ToastGlyphMotion(), trigger: gestured) { content, motion in
                    content.rotationEffect(.degrees(motion.angle), anchor: UnitPoint(x: 0.5, y: 0.8))
                } keyframes: { _ in
                    KeyframeTrack(\.angle) {
                        CubicKeyframe(-16, duration: 0.09)
                        CubicKeyframe(12, duration: 0.11)
                        CubicKeyframe(-6, duration: 0.11)
                        CubicKeyframe(0, duration: 0.14)
                    }
                }
        case .working:
            EmptyView()
        }
    }

    /// The working ring: a faint track and a yellow quarter that turns once every 0.9 s, read from the clock (an animation that
    /// repeats forever would carry the pill's own changes along with it).
    private var ring: some View {
        let line = size * 0.1
        return ZStack {
            Circle().stroke(Palette.Toast.ringTrack, lineWidth: line)
            TimelineView(.animation) { context in
                let turn = context.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 0.9) / 0.9
                Circle()
                    .trim(from: 0, to: 0.25)
                    .stroke(Palette.Toast.ring, style: StrokeStyle(lineWidth: line, lineCap: .round))
                    .rotationEffect(.degrees(turn * 360 - 90))
            }
        }
        .padding(line / 2 + 1)
    }

    /// The disc grows in from half its size (0.32 s, with a little overshoot); the ✓ draws from 0.2 s, the ★ turns in from 0.1 s,
    /// the ! shakes from 0.2 s, each done by about 0.6 s (`ToastService` taps at the same moments).
    private func arrive() async {
        if kind == .working {
            arrived = true
            return
        }
        guard !reduceMotion else { return }
        withAnimation(.spring(duration: 0.32, bounce: 0.35).delay(0.05)) { arrived = true }
        try? await Task.sleep(for: Duration.milliseconds(kind == .cue ? 100 : 200))
        guard !Task.isCancelled else { return }
        if kind == .done {
            withAnimation(.easeOut(duration: 0.3)) { drawn = true }
        } else {
            gestured = true
        }
    }
}

#if DEBUG
#Preview {
    HStack(spacing: 16) {
        ToastIcon(kind: .done)
        ToastIcon(kind: .cue)
        ToastIcon(kind: .problem)
        ToastIcon(kind: .working)
    }
    .padding()
    .background(Palette.Toast.fill)
}
#endif
