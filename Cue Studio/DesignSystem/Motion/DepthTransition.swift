//
//  DepthTransition.swift
//  Cue Studio
//

import SwiftUI

/// A screen changing as if the camera moved through the night: the one leaving falls back (a little smaller, a little up, out of focus) and
/// the next comes forward from just in front of the glass (a little bigger, a little low, out of focus) into place. Scale, focus and a few
/// points of travel are enough for depth; nothing turns in 3D. The leaving and arriving halves have their own curves (`CueMotion.chapterExit`,
/// `chapterEnter`), so the two never move at the same time and in the same rhythm.
struct DepthTransition: Transition {
    /// How far the arriving screen starts in front (× its size) and the leaving one ends behind.
    var nearScale = 1.03
    var farScale = 0.97
    /// Points of travel: the arriving screen rises into place, the leaving one drifts up as it recedes.
    var rise: CGFloat = 14
    var drift: CGFloat = -8
    /// Out of focus at the ends, in points of blur.
    var focus: CGFloat = 4

    func body(content: Content, phase: TransitionPhase) -> some View {
        content
            .scaleEffect(scale(phase))
            .offset(y: offset(phase))
            .blur(radius: phase.isIdentity ? 0 : focus)
            .opacity(phase.isIdentity ? 1 : 0)
    }

    private func scale(_ phase: TransitionPhase) -> CGFloat {
        if phase.isIdentity { return 1 }
        return phase == .willAppear ? nearScale : farScale
    }

    private func offset(_ phase: TransitionPhase) -> CGFloat {
        if phase.isIdentity { return 0 }
        return phase == .willAppear ? rise : drift
    }
}

extension AnyTransition {
    /// The chapters of a story: `DepthTransition`, each half on its own curve; a plain fade with Reduce Motion.
    static func depth(reduceMotion: Bool) -> AnyTransition {
        guard !reduceMotion else { return .opacity.animation(CueMotion.fade) }
        return .asymmetric(
            insertion: AnyTransition(DepthTransition()).animation(CueMotion.chapterEnter),
            removal: AnyTransition(DepthTransition()).animation(CueMotion.chapterExit)
        )
    }
}
