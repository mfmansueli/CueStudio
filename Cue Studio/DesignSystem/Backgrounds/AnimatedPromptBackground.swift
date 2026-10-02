//
//  AnimatedPromptBackground.swift
//  Cue Studio
//

import SwiftUI

/// A quiet golden wash. Only this decorative layer redraws; the card owns its clipping mask.
struct AnimatedPromptBackground: View {
    var base: Color = Palette.surface2
    var isActive = true

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @State private var isOnScreen = false
    @State private var isScrollVisible = true
    @State private var clock = MotionClock()

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 24, paused: !isRunning)) { context in
            GeometryReader { geometry in
                let time = reduceMotion ? 0 : clock.elapsed(at: context.date)
                let phase = time * 2 * .pi / 16
                let secondPhase = time * 2 * .pi / 19 + .pi / 3
                let radius = max(geometry.size.width, geometry.size.height)

                ZStack {
                    base
                    LinearGradient(
                        colors: [Palette.accWash.opacity(0.25), Palette.accWashFaint.opacity(0.7)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    ZStack {
                        RadialGradient(
                            colors: [Palette.acc.opacity(0.34), .clear],
                            center: UnitPoint(x: 0.25 + 0.24 * sin(phase), y: 0.15 + 0.18 * sin(phase + 0.5)),
                            startRadius: 0,
                            endRadius: radius * 0.65
                        )
                        RadialGradient(
                            colors: [Palette.acc.opacity(0.13), .clear],
                            center: UnitPoint(x: 0.72 + 0.2 * sin(secondPhase), y: 0.3 + 0.18 * cos(secondPhase)),
                            startRadius: 0,
                            endRadius: radius * 0.56
                        )
                        RadialGradient(
                            colors: [Palette.insetShade, .clear],
                            center: UnitPoint(x: 0.55 + 0.2 * cos(secondPhase), y: 0.7 + 0.14 * sin(phase)),
                            startRadius: 0,
                            endRadius: radius * 0.58
                        )
                    }
                    // Overscan the blur so its rectangular edges never reach the card's mask.
                    .padding(-24)
                    .blur(radius: 12)
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .transaction { $0.animation = nil }
        .onAppear { isOnScreen = true }
        .onDisappear {
            isOnScreen = false
            clock.setRunning(false, at: .now)
        }
        .onScrollVisibilityChange(threshold: 0.01) { isScrollVisible = $0 }
        .onChange(of: isRunning, initial: true) { _, running in
            clock.setRunning(running, at: .now)
        }
    }

    private var isRunning: Bool {
        isActive && isOnScreen && isScrollVisible && scenePhase == .active && !reduceMotion
    }

    /// Keeps the last frame while paused, then resumes without counting time spent off screen.
    struct MotionClock {
        private var accumulated: TimeInterval = 0
        private var startedAt: Date?

        func elapsed(at date: Date) -> TimeInterval {
            accumulated + (startedAt.map { max(0, date.timeIntervalSince($0)) } ?? 0)
        }

        mutating func setRunning(_ running: Bool, at date: Date) {
            if running {
                if startedAt == nil { startedAt = date }
            } else if startedAt != nil {
                accumulated = elapsed(at: date)
                startedAt = nil
            }
        }
    }
}
