//
//  OnboardingChrome.swift
//  Cue Studio
//

import SwiftUI

/// The five-segment bar at the top of the first flight. There is no Skip: every new creator goes through the whole flight (the owner's call).
struct OnboardingChrome: View {
    let step: OnboardingStep

    var body: some View {
        HStack(spacing: 5) {
            ForEach(0..<OnboardingStep.segmentCount, id: \.self) { index in
                let reached = (step.segment ?? -1)
                Capsule()
                    .fill(index < reached ? Color.white.opacity(0.85) : index == reached ? Palette.acc : Palette.fill)
                    .frame(width: 22, height: 4)
            }
            .animation(CueMotion.card, value: step)
            Spacer(minLength: 8)
        }
        // A 44 pt row, so the chapters below sit where the boards put them.
        .frame(height: Metrics.hitTarget)
        .padding(.horizontal, 20)
    }
}
