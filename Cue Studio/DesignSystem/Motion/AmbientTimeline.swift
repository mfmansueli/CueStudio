//
//  AmbientTimeline.swift
//  Cue Studio
//

import SwiftUI

/// The clock of an ambient loop (a breath, a sweep, an orbit, a pulse): a `TimelineView(.animation)` that only ticks while someone can see
/// it. It stops on its frame when the view is off screen or scrolled out, when the app is not active (a call, Control Center, the app
/// switcher) and with Reduce Motion, and when it starts again the loop goes on from where it was (`MotionClock`), never skipping ahead. Low
/// Power Mode stops nothing (the owner's rule). Every loop of the app runs on one of these, so none keeps drawing behind the prompter, the
/// editor or a sheet.
struct AmbientTimeline<Content: View>: View {
    /// Seconds between frames: 1/30 for what is ambient, nil for the display's own rate.
    var interval: Double? = 1.0 / 30
    /// The caller's own reason to stand still (the loop is over, it is not its moment).
    var paused = false
    /// Reduce Motion stills it (and `seconds` is 0); a loop that carries information (a meter) passes false.
    var stillsWithReduceMotion = true
    @ViewBuilder let content: (AmbientTime) -> Content

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @State private var isOnScreen = false
    @State private var isScrollVisible = true
    @State private var clock = MotionClock()

    private var isStilled: Bool { stillsWithReduceMotion && reduceMotion }

    private var isRunning: Bool {
        !paused && !isStilled && isOnScreen && isScrollVisible && scenePhase == .active
    }

    var body: some View {
        TimelineView(.animation(minimumInterval: interval, paused: !isRunning)) { context in
            content(AmbientTime(seconds: isStilled ? 0 : clock.elapsed(at: context.date), date: context.date, isStill: !isRunning))
        }
        .onAppear { isOnScreen = true }
        .onDisappear {
            isOnScreen = false
            clock.setRunning(false, at: .now)
        }
        .onScrollVisibilityChange(threshold: 0.01) { isScrollVisible = $0 }
        .onChange(of: isRunning, initial: true) { _, running in clock.setRunning(running, at: .now) }
    }
}
