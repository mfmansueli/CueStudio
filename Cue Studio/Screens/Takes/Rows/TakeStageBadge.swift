//
//  TakeStageBadge.swift
//  Cue Studio
//

import SwiftUI

/// "● PICK BEST", "● IN EDIT", "● READY", "✦ SHARED": the stage on a video's poster, on a dark pill; READY's dot glows, SHARED has the yellow star.
struct TakeStageBadge: View {
    let stage: TakeStage

    var body: some View {
        HStack(spacing: 5) {
            if stage == .shared {
                Text(verbatim: "✦").foregroundStyle(Palette.acc)
            } else {
                Circle().fill(stage.boardTint).frame(width: 5, height: 5)
                    .shadow(color: stage == .ready ? stage.boardTint : .clear, radius: 6)
            }
            Text(stage.badgeLabel)
                .textCase(.uppercase)
                .lineLimit(1)
        }
        .font(.system(size: 10, weight: .semibold, design: .monospaced))
        .foregroundStyle(stage.boardTint)
        .padding(.horizontal, 7)
        .frame(height: 22)
        .background(Palette.posterPill, in: Capsule())
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
