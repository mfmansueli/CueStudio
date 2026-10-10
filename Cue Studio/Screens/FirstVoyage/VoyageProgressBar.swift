//
//  VoyageProgressBar.swift
//  Cue Studio
//

import SwiftUI

/// The six segments of the first voyage: yellow when done, the track's gray ahead. A segment whose light is being shown fills from the
/// left and glows; one done but not lit yet (`unlit`) waits empty for that moment.
struct VoyageProgressBar: View {
    let done: Set<VoyageStep>
    /// Done, but the card hasn't lit it up yet.
    var unlit: Set<VoyageStep> = []
    /// Lighting up now.
    var lighting: Set<VoyageStep> = []

    var body: some View {
        HStack(spacing: 4) {
            ForEach(VoyageStep.allCases) { step in
                let isFilled = done.contains(step) && (!unlit.contains(step) || lighting.contains(step))
                Capsule()
                    .fill(Palette.surface3)
                    .overlay(alignment: .leading) {
                        Capsule()
                            .fill(Palette.acc)
                            .scaleEffect(x: isFilled ? 1 : 0, anchor: .leading)
                    }
                    .shadow(color: lighting.contains(step) ? Palette.acc : .clear, radius: 6)
                    .frame(height: 4)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Steps done"))
        .accessibilityValue(Text("\(done.count) of \(VoyageProgress.stepCount)"))
    }
}
