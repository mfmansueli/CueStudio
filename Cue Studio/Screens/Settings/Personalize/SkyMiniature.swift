//
//  SkyMiniature.swift
//  Cue Studio
//

import SwiftUI

/// One of the starry skies, live, in a small window: the same night glow (`BgWash`) and stars (`StarfieldView`) the browse screens draw
/// behind them at that density, whatever the creator has chosen. Settings › Personalize shows each sky this way, and the chosen one in its
/// hero. Off is the night alone.
struct SkyMiniature: View {
    let density: SkyDensity

    var body: some View {
        ZStack {
            BgWash(lights: BgWash.browse(density), base: BgWash.browseBase(density))
            // The stars at full strength: in a small window the browse screens' delicate stars would barely show.
            StarfieldView(density: density, look: StarfieldMath.boardLook)
        }
        .accessibilityHidden(true)
    }
}
