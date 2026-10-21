//
//  ReviewPauseFlash.swift
//  Cue Studio
//

import SwiftUI

/// The pause sign that blinks where Play will come back, when a tap on the video pauses it (as Photos does): it swells in, grows a little
/// more and fades, in about 0.65 s. With Reduce Motion it only fades. Decorative: the paused video and the Play button say the rest.
struct ReviewPauseFlash: View {
    /// Each change blinks it once.
    let trigger: Int

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let still = reduceMotion
        return Image(systemName: "pause.fill")
            .font(.system(size: 28, weight: .semibold))
            .foregroundStyle(Palette.ink)
            .frame(width: 76, height: 76)
            .background(Color.black.opacity(0.35), in: Circle())
            .keyframeAnimator(initialValue: Frame(), trigger: trigger) { content, frame in
                content
                    .scaleEffect(still ? 1 : frame.scale)
                    .opacity(trigger == 0 ? 0 : frame.opacity)
            } keyframes: { _ in
                KeyframeTrack(\.opacity) {
                    LinearKeyframe(0, duration: 0)
                    LinearKeyframe(1, duration: 0.14)
                    LinearKeyframe(1, duration: 0.12)
                    LinearKeyframe(0, duration: 0.39)
                }
                KeyframeTrack(\.scale) {
                    LinearKeyframe(0.8, duration: 0)
                    SpringKeyframe(1, duration: 0.2, spring: .snappy)
                    LinearKeyframe(1.18, duration: 0.45)
                }
            }
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }

    struct Frame {
        var opacity: Double = 0
        var scale: Double = 0.8
    }
}
