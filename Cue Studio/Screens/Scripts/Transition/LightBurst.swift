//
//  LightBurst.swift
//  Cue Studio
//

import SwiftUI

/// A light that bursts and goes as `progress` runs 0 → 1: it grows from `from` to `to` times its size and fades from `peak` to nothing, and
/// it isn't there at rest (before or after). `Animatable`, so the fade is worked out from every in-between value: an opacity written from
/// `progress` in the view stays at its end value (nothing) while the animation runs, and the light was never seen.
struct LightBurst: ViewModifier, Animatable {
    var progress: CGFloat
    var from: CGFloat
    var to: CGFloat
    var peak: Double

    var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }

    func body(content: Content) -> some View {
        content
            .scaleEffect(from + (to - from) * progress)
            .opacity(progress > 0 && progress < 1 ? peak * Double(1 - progress) : 0)
    }
}
