//
//  MotionScreen.swift
//  Cue Studio
//

import SwiftUI

/// The single clock of a screen whose motion comes from a board: one `TimelineView(.animation)` that hands the scene its second, so no
/// layer runs a clock (or a `withAnimation`) of its own. The choreography plays once and holds at `hold`; with `loops` the ambient motion
/// goes on after it. Reduce Motion shows the final frame and nothing moves; Low Power Mode does not stop anything (the owner wants the motion to play
/// in every situation). Off screen or with the app not active the clock stops (`MotionClock`) and the scene stays on its frame: coming back
/// it goes on from there, never skipping ahead by the time it was away. A frozen second is for UI tests that take pictures. A tap anywhere
/// jumps to the final state when `skippable`.
struct MotionScreen<Content: View>: View {
    /// The second of the timeline at which the scene is complete.
    let hold: Double
    /// Ambient loops keep running once the choreography is over.
    var loops = false
    var skippable = false
    /// A second to stand still at (UI tests taking pictures); nil plays.
    var frozenAt: Double?
    /// False shows the final frame at once (a screen that plays only the first time).
    var plays = true
    /// How often the ambient motion redraws once the choreography is over (seconds; 1/30 by default, it is not a moment to look at).
    var ambientInterval = 1.0 / 30
    /// Called once, when the timeline reaches `hold`.
    var onFinish: (() -> Void)?
    @ViewBuilder let content: (MotionTime) -> Content

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @State private var clock = MotionClock()
    @State private var isOnScreen = false
    @State private var skipped = false
    @State private var finished = false

    private var animates: Bool {
        plays && frozenAt == nil && !reduceMotion
    }

    /// The clock runs: the scene plays, is on screen and the app is in front.
    private func runs(onScreen: Bool, phase: ScenePhase) -> Bool {
        animates && onScreen && phase == .active
    }

    var body: some View {
        TimelineView(.animation(
            minimumInterval: finished ? ambientInterval : nil,
            paused: !runs(onScreen: isOnScreen, phase: scenePhase) || (finished && !loops)
        )) { context in
            let elapsed = clock.elapsed(at: context.date)
            content(time(elapsed: elapsed, now: context.date))
                .onChange(of: elapsed >= hold || skipped) { _, isOver in
                    if isOver, !finished {
                        finished = true
                        onFinish?()
                    }
                }
        }
        .onAppear {
            isOnScreen = true
            clock.setRunning(runs(onScreen: true, phase: scenePhase), at: .now)
        }
        .onDisappear {
            isOnScreen = false
            clock.setRunning(false, at: .now)
        }
        .onChange(of: scenePhase) { _, phase in clock.setRunning(runs(onScreen: isOnScreen, phase: phase), at: .now) }
        // A skip settles in 0.3 s (what is drawn as views eases to its final place; a canvas is redrawn at the end).
        .simultaneousGesture(TapGesture().onEnded {
            if skippable, animates { withAnimation(CueMotion.skipSettle) { skipped = true } }
        }, isEnabled: skippable)
    }

    private func time(elapsed: Double, now: Date) -> MotionTime {
        if let frozenAt { return MotionTime(clock: min(frozenAt, hold), ambient: frozenAt, isStill: true, now: now) }
        guard animates else { return MotionTime(clock: hold, ambient: 0, isStill: true, now: now) }
        if skipped { return MotionTime(clock: hold, ambient: elapsed, isStill: false, now: now) }
        return MotionTime(clock: min(elapsed, hold), ambient: elapsed, isStill: false, now: now)
    }
}
