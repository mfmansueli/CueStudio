//
//  TakeFirstStarPill.swift
//  Cue Studio
//

import SwiftUI

/// "✦ FIRST STAR" on the first video's card or row in Takes, when its review was left without a confirmed post (D4, owner 09/11/2026: no
/// full screen; the moment stays in place). It lights once as it appears: the pill opens from 60 %, and a ring of light leaves the star. Under
/// Reduce Motion it only fades in. The card's own label says it to VoiceOver ("First star"), and Takes announces it once.
struct TakeFirstStarPill: View {
    /// On a poster (the grid) it sits on the dark pill of the stage's badge; in the list, on the row's chip surface.
    let onPoster: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isLit = false
    @State private var ringOut = false

    var body: some View {
        HStack(spacing: 5) {
            Text(verbatim: "✦")
                .overlay {
                    if !reduceMotion {
                        Circle()
                            .stroke(Palette.acc, lineWidth: 1)
                            .frame(width: 12, height: 12)
                            .scaleEffect(ringOut ? 3.4 : 0.5)
                            .opacity(ringOut ? 0 : 0.9)
                            .allowsHitTesting(false)
                    }
                }
            Text("FIRST STAR")
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .monoFont(size: 10, weight: .heavy)
        .interfaceTracking(0.5)
        .foregroundStyle(Palette.accText)
        .padding(.horizontal, 8)
        .frame(minHeight: 22)
        .background(onPoster ? Palette.Takes.posterPill : Palette.surface2, in: Capsule())
        .scaleEffect(isLit || reduceMotion ? 1 : 0.6)
        .opacity(isLit ? 1 : 0)
        .onAppear(perform: light)
        .accessibilityHidden(true)
        .accessibilityIdentifier("takes.firstStar")
    }

    private func light() {
        guard !isLit else { return }
        if reduceMotion {
            withAnimation(.easeOut(duration: 0.3)) { isLit = true }
            return
        }
        withAnimation(.spring(response: 0.45, dampingFraction: 0.62).delay(0.25)) { isLit = true }
        withAnimation(.easeOut(duration: 0.9).delay(0.35)) { ringOut = true }
    }
}

#if DEBUG
#Preview {
    VStack(spacing: 12) {
        TakeFirstStarPill(onPoster: true)
        TakeFirstStarPill(onPoster: false)
    }
    .padding()
    .background(Palette.bg)
}
#endif
