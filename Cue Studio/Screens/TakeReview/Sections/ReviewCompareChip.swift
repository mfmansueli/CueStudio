//
//  ReviewCompareChip.swift
//  Cue Studio
//

import SwiftUI

/// "● ▬ ●  2 / 3": where this take is among the video's takes. Swiping the video (or tapping a
/// side of the chip) goes to the next or the previous one, to compare them.
struct ReviewCompareChip: View {
    let count: Int
    let index: Int
    let label: String
    let onPrevious: (() -> Void)?
    let onNext: (() -> Void)?

    var body: some View {
        HStack(spacing: 10) {
            Button { onPrevious?() } label: {
                Image(systemName: "chevron.left").font(.system(size: 11, weight: .bold))
                    .frame(width: 20, height: 30)
                    .contentShape(Rectangle().inset(by: -12))
            }
                .disabled(onPrevious == nil)
                .accessibilityLabel(Text("Previous take"))
                .accessibilityIdentifier("review.previousTake")
            HStack(spacing: 4) {
                ForEach(0..<count, id: \.self) { position in
                    Capsule()
                        .fill(position == index ? Color.white : Color.white.opacity(0.35))
                        .frame(width: position == index ? 14 : 5, height: 5)
                }
            }
            .accessibilityHidden(true)
            Text(label)
                .font(.system(size: 12, weight: .heavy, design: .monospaced))
                .tracking(0.5)
            Button { onNext?() } label: {
                Image(systemName: "chevron.right").font(.system(size: 11, weight: .bold))
                    .frame(width: 20, height: 30)
                    .contentShape(Rectangle().inset(by: -12))
            }
                .disabled(onNext == nil)
                .accessibilityLabel(Text("Next take"))
                .accessibilityIdentifier("review.nextTake")
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 12)
        .frame(height: 30)
        .glassEffect(.regular, in: Capsule())
        .buttonStyle(.plain)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("review.compareChip")
    }
}
