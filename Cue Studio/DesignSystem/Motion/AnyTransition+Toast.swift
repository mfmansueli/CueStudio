//
//  AnyTransition+Toast.swift
//  Cue Studio
//

import SwiftUI

extension AnyTransition {
    /// A toast (`motion/README.md`: in 0.25 s from 8 pt above, out 0.2 s): it settles a few points into place on light's curve instead of
    /// falling from the top of the screen, and leaves by fading, quicker, so a new toast replacing it never crosses it in flight.
    static func toast(reduceMotion: Bool) -> AnyTransition {
        guard !reduceMotion else { return .opacity.animation(CueMotion.fade) }
        return .asymmetric(
            insertion: .opacity.combined(with: .offset(y: -8)).animation(CueMotion.light(duration: 0.25)),
            removal: .opacity.animation(.easeOut(duration: 0.2))
        )
    }
}
