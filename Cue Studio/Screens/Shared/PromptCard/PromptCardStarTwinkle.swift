//
//  PromptCardStarTwinkle.swift
//  Cue Studio
//

import SwiftUI

/// The three small stars beside the Prompt title, with one quiet twinkle at a time.
struct PromptCardStarTwinkle: View {
    var isActive = true

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @State private var isOnScreen = false
    @State private var isScrollVisible = true
    @State private var clock = AnimatedPromptBackground.MotionClock()

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 24, paused: !isRunning)) { context in
            let time = reduceMotion ? 0 : clock.elapsed(at: context.date)

            ZStack {
                ForEach(Star.allCases) { star in
                    let twinkle = TwinkleSchedule.progress(for: star, at: time)

                    ZStack {
                        Image(systemName: "sparkle")
                            .font(.system(size: star.size, weight: .medium))
                            .foregroundStyle(Palette.acc)
                            .opacity(0.86 + twinkle * 0.14)
                            .scaleEffect(1 + twinkle * 0.40)
                            .shadow(
                                color: Palette.acc.opacity(twinkle * 0.42),
                                radius: 1.4 + twinkle * 3.6
                            )
                        Image(systemName: "sparkle")
                            .font(.system(size: star.size, weight: .medium))
                            .foregroundStyle(Palette.acc.opacity(twinkle * 0.60))
                            .scaleEffect(1 + twinkle * 0.14)
                            .blur(radius: 0.9 + twinkle * 1.2)
                        Circle()
                            .fill(.white.opacity(twinkle * 0.72))
                            .frame(width: 1.2 + twinkle * 1.0, height: 1.2 + twinkle * 1.0)
                            .blur(radius: 0.06)
                    }
                    .frame(width: star.size, height: star.size)
                    .offset(star.offset)
                }
            }
            .frame(width: Self.canvasSize, height: Self.canvasSize)
        }
        .frame(width: Self.canvasSize, height: Self.canvasSize)
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

    private static let canvasSize: CGFloat = 18

    private var isRunning: Bool {
        isActive && isOnScreen && isScrollVisible && scenePhase == .active && !reduceMotion
    }

    enum Star: CaseIterable, Identifiable {
        case large
        case small
        case medium

        var id: Self { self }

        var size: CGFloat {
            switch self {
            case .large: 11
            case .small: 5
            case .medium: 8
            }
        }

        var offset: CGSize {
            switch self {
            case .large: CGSize(width: -3.5, height: -2.5)
            case .small: CGSize(width: 4, height: -5.5)
            case .medium: CGSize(width: 3.5, height: 3.5)
            }
        }
    }

    /// Fixed, uneven intervals make the stars feel observed rather than scheduled.
    enum TwinkleSchedule {
        static let cycleDuration: TimeInterval = 21
        static let events: [PromptCardTwinkleEvent] = [
            PromptCardTwinkleEvent(star: .large, start: 0.63, duration: 1.15),
            PromptCardTwinkleEvent(star: .small, start: 2.8, duration: 0.85),
            PromptCardTwinkleEvent(star: .medium, start: 4.97, duration: 1.25),
            PromptCardTwinkleEvent(star: .small, start: 7.0, duration: 0.9),
            PromptCardTwinkleEvent(star: .large, start: 9.38, duration: 1.0),
            PromptCardTwinkleEvent(star: .medium, start: 11.48, duration: 0.8),
            PromptCardTwinkleEvent(star: .small, start: 13.65, duration: 1.1),
            PromptCardTwinkleEvent(star: .large, start: 15.96, duration: 0.95),
            PromptCardTwinkleEvent(star: .medium, start: 18.48, duration: 0.9),
        ]

        static func progress(for star: Star, at time: TimeInterval) -> Double {
            let cycleTime = time.truncatingRemainder(dividingBy: cycleDuration)
            guard let event = events.first(where: {
                $0.star == star && cycleTime >= $0.start && cycleTime <= $0.start + $0.duration
            }) else {
                return 0
            }

            let phase = (cycleTime - event.start) / event.duration
            return sin(phase * .pi)
        }
    }
}

struct PromptCardTwinkleEvent {
    let star: PromptCardStarTwinkle.Star
    let start: TimeInterval
    let duration: TimeInterval
}

#if DEBUG
#Preview {
    HStack(spacing: 8) {
        PromptCardStarTwinkle()
        Text("Prompt")
            .font(.title3.bold())
    }
    .padding()
    .background(Palette.surface2)
}
#endif
