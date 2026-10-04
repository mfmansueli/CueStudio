//
//  TakeStageBadge.swift
//  Cue Studio
//

import SwiftUI

/// "● PICK BEST", "● IN EDIT", "● READY", "● SHARED": the stage on a video's poster, on a dark
/// glass pill with a ring in the stage's color.
struct TakeStageBadge: View {
    let stage: TakeStage

    var body: some View {
        HStack(spacing: 5) {
            Circle().fill(stage.pillTint).frame(width: 5, height: 5)
            Text(stage.badgeLabel)
                .textCase(.uppercase)
                .lineLimit(1)
        }
        .font(.system(size: 10, weight: .heavy, design: .monospaced))
        .tracking(0.5)
        .foregroundStyle(stage.pillTint)
        .padding(.horizontal, 7)
        .frame(height: 22)
        .background(Palette.posterPill, in: Capsule())
        .overlay(Capsule().strokeBorder(stage.pillRing, lineWidth: 1))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(stage.sentence))
    }
}

#if DEBUG
#Preview {
    VStack(spacing: 8) {
        ForEach(TakeStage.allCases) { TakeStageBadge(stage: $0) }
    }
    .padding()
    .background(Color.gray)
}
#endif
