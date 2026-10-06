//
//  OnboardingSky.swift
//  Cue Studio
//

import SwiftUI

/// The sky behind the first flight. On the welcome it comes in as the board has it (`wl1`: it fades in while it settles from ×1.3 to ×1
/// in 2.6 s, `cubic-bezier(.12,.9,.25,1)`); in every chapter after, and with Reduce Motion, it is simply there.
struct OnboardingSky: View {
    let step: OnboardingStep
    /// The welcome plays its opening (it does not in UI tests that don't ask for it).
    let plays: Bool
    /// A second of the welcome's timeline to stand still at (UI tests taking pictures); nil plays.
    var frozenAt: Double?

    @Environment(SkyDirector.self) private var director

    private static let clip = MotionLibrary.clip("1.1_welcome")
    /// The second the sky is settled.
    private static let settled = 2.6

    var body: some View {
        MotionScreen(hold: Self.settled, frozenAt: step == .welcome ? frozenAt : nil, plays: plays && step == .welcome) { time in
            // The sky the boards were drawn with: 7 twinkles and the comet (Calm, which used to have them, is now only the stars).
            StarfieldView(density: .calm, seed: 7, twinkleCountOverride: 7, cometOverride: true, look: StarfieldMath.boardLook)
                .motion(step == .voyage ? director.pose : Self.clip.pose(of: "L1", at: time.clock))
        }
    }
}

#if DEBUG
#Preview {
    OnboardingSky(step: .universe, plays: false)
        .environment(SkyDirector())
}
#endif
