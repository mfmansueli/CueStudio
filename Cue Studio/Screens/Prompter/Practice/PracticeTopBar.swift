//
//  PracticeTopBar.swift
//  Cue Studio
//

import SwiftUI

/// The top of the practice (1.6): the first flight's five segments (the fourth is this chapter, as it is the permissions') and, at the other end, the one
/// status label the practice has: "✦ PRACTICE · NOT RECORDING".
struct PracticeTopBar: View {
    var body: some View {
        HStack(spacing: 10) {
            HStack(spacing: 5) {
                ForEach(0..<OnboardingStep.segmentCount, id: \.self) { index in
                    let reached = OnboardingStep.practice.segment ?? 3
                    Capsule()
                        .fill(index < reached ? Color.white.opacity(0.85) : index == reached ? Palette.acc : Color.white.opacity(0.3))
                        .frame(width: 22, height: 4)
                }
            }
            Spacer(minLength: 8)
            HStack(spacing: 6) {
                Text(verbatim: "✦").foregroundStyle(Palette.Flight.lilac)
                Text("PRACTICE · NOT RECORDING")
            }
            .font(.system(size: 10, weight: .semibold, design: .monospaced))
            .tracking(0.8)
            .foregroundStyle(Palette.aiTextStrong)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .padding(.horizontal, 10)
            .frame(height: 26)
            .glassEffect(.regular, in: .capsule)
            .accessibilityIdentifier("practice.chip")
        }
        .padding(.horizontal, 20)
    }
}
