//
//  ProOpening.swift
//  Cue Studio
//

import SwiftUI

/// Plays `ProOpeningScript` over `content` and tells the content which second it is (so each block can fade up in its turn). Once; tappable from
/// 1.4 s to skip to the end. With Reduce Motion, and in the calm Pro, there is no warp, core, ring or flash: the content fades in
/// over 0.3 s. Haptics: `.soft` at the ignition (1.25 s), `.success` when the last block lands.
struct ProOpening<Content: View>: View {
    let plays: Bool
    /// Where the planet that is you sits, from the top of the screen.
    let planetY: CGFloat
    @ViewBuilder let content: (_ time: Double) -> Content

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.proOpeningFrozenAt) private var frozenAt
    @State private var start = Date.now
    @State private var isFinished = false
    @State private var isSkipped = false
    @State private var fadedIn = false

    private var animates: Bool { plays && frozenAt == nil && !reduceMotion && !isSkipped }

    var body: some View {
        TimelineView(.animation(paused: !animates || isFinished)) { context in
            let time = frozenAt ?? (animates ? min(ProOpeningScript.settled, context.date.timeIntervalSince(start)) : ProOpeningScript.settled)
            ZStack {
                content(time)
                if plays, time < ProOpeningScript.duration, frozenAt != nil || animates {
                    // The whole screen: the focus (44% of its height) and the planet's place (`planetY`) are measured from its top edge.
                    ProOpeningCanvas(time: time, planetY: planetY).ignoresSafeArea()
                    if time >= ProOpeningScript.tappableFrom {
                        Color.clear
                            .contentShape(Rectangle())
                            .ignoresSafeArea()
                            .onTapGesture { isSkipped = true }
                            .accessibilityHidden(true)
                    }
                }
            }
        }
        // Without the warp the content comes in with a plain fade.
        .opacity(animates || frozenAt != nil || fadedIn ? 1 : 0)
        .onAppear { if !animates { withAnimation(.easeOut(duration: 0.3)) { fadedIn = true } } }
        .task(id: plays) { await run() }
    }

    private func run() async {
        guard animates else { return }
        start = .now
        isFinished = false
        for (second, beat) in [(ProOpeningScript.ignitionBeat, false), (ProOpeningScript.landing, true)] {
            let wait = second - Date.now.timeIntervalSince(start)
            if wait > 0 { try? await Task.sleep(for: .seconds(wait)) }
            if Task.isCancelled || isSkipped { return }
            if beat { Haptics.success() } else { Haptics.soft() }
        }
        try? await Task.sleep(for: .seconds(max(0, ProOpeningScript.settled + 0.1 - Date.now.timeIntervalSince(start))))
        isFinished = true
    }
}
