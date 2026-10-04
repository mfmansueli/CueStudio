//
//  EmptyStateMark.swift
//  Cue Studio
//

import SwiftUI

/// The ring, its violet core and the star that orbits it.
struct EmptyStateMark: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @State private var isOnScreen = false
    @State private var isLowPower = ProcessInfo.processInfo.isLowPowerModeEnabled

    /// One turn of the star, in seconds.
    static let turnDuration: TimeInterval = 9
    /// Where the star rests when nothing moves: top right (−45° from the top).
    static let restingAngle = Angle.degrees(45)

    private var isRunning: Bool { isOnScreen && scenePhase == .active && !reduceMotion && !isLowPower }

    var body: some View {
        let size = Metrics.emptyRingSize
        TimelineView(.animation(minimumInterval: 1.0 / 30, paused: !isRunning)) { context in
            let angle = isRunning
                ? Angle.degrees(context.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: Self.turnDuration) / Self.turnDuration * 360)
                : Self.restingAngle
            ZStack {
                Circle()
                    .fill(RadialGradient(colors: [Palette.emptyRingCore, .clear], center: .center, startRadius: 0, endRadius: size / 2))
                Circle().strokeBorder(Palette.emptyRing, lineWidth: 1)
                Circle()
                    .fill(Palette.emptyOrbiter)
                    .frame(width: Metrics.emptyOrbiterSize, height: Metrics.emptyOrbiterSize)
                    .shadow(color: Palette.emptyOrbiterGlow, radius: 4)
                    .offset(y: -(size / 2 - 0.5))
                    .rotationEffect(angle)
            }
            .frame(width: size, height: size)
        }
        .frame(width: size, height: size)
        .onAppear { isOnScreen = true }
        .onDisappear { isOnScreen = false }
        .onReceive(NotificationCenter.default.publisher(for: .NSProcessInfoPowerStateDidChange)) { _ in
            isLowPower = ProcessInfo.processInfo.isLowPowerModeEnabled
        }
        .accessibilityHidden(true)
    }
}

#if DEBUG
#Preview {
    EmptyStateMark().padding().background(Palette.bg)
}
#endif
