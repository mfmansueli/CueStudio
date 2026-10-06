//
//  PracticeBoxOverlay.swift
//  Cue Studio
//

import SwiftUI

/// What lies over the practice's text box (1.6, 09 §17): the text recedes behind a dim, blurred layer with a play button and "TAP TO START";
/// the tap squeezes the button and Cue counts the creator in ("GET READY", 3 · 2 · 1 with a ring that fills in a second each, then "READ!"),
/// and the dim lifts as the text begins to move. Every moving part reads the board's layer at the board's second of the moment.
struct PracticeBoxOverlay: View {
    let stage: PracticeStage
    let onPlay: () -> Void

    /// UI tests taking pictures: the overlay stands still at this second of the board.
    @Environment(\.onboardingChapterFrozenAt) private var frozenAt

    private static let clip = MotionLibrary.clip("1.6_practice")
    /// The board waits on this second until it is tapped.
    private static let idleSecond = 1.5

    var body: some View {
        TimelineView(.animation(paused: !isCounting || frozenAt != nil)) { context in
            let second = boardSecond(at: context.date)
            ZStack {
                Palette.flightDim.opacity(0.7 * pose("L1", second).opacity)
                label(second)
                rings(second)
                numbers(second)
                playButton(second)
            }
        }
        .allowsHitTesting(stage == .idle)
    }

    private var isCounting: Bool {
        if case .counting = stage { return true }
        return false
    }

    /// The board's second: waiting on the idle frame, or the time since the tap added to the second of the tap.
    private func boardSecond(at date: Date) -> Double {
        if let frozenAt { return frozenAt }
        return switch stage {
        case .idle: Self.idleSecond
        case .counting(let since): PracticeStage.tapSecond + date.timeIntervalSince(since)
        case .reading, .done: 20
        }
    }

    private func pose(_ layer: String, _ second: Double) -> MotionPose { Self.clip.pose(of: layer, at: second) }

    private func label(_ second: Double) -> some View {
        VStack {
            Text("GET READY")
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .tracking(1.76)
                .foregroundStyle(Palette.starGold)
                .motion(pose("L2", second))
                .padding(.top, 20)
            Spacer()
        }
    }

    /// A ring of 116 pt for each number: a faint track and a yellow arc that closes in the second of that number.
    private func rings(_ second: Double) -> some View {
        ZStack {
            ForEach([("L3", "L4"), ("L5", "L6"), ("L7", "L8")], id: \.0) { track, arc in
                let trackPose = pose(track, second)
                let arcPose = pose(arc, second)
                Circle().stroke(Color.white.opacity(0.14), lineWidth: 2).opacity(trackPose.opacity)
                Circle()
                    .trim(from: 0, to: arcPose.drawn)
                    .stroke(Palette.acc, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .shadow(color: Palette.acc.opacity(0.8), radius: 6)
                    .opacity(arcPose.opacity)
            }
        }
        .frame(width: 116, height: 116)
    }

    private func numbers(_ second: Double) -> some View {
        ZStack {
            ForEach([("3", "L9"), ("2", "L10"), ("1", "L11")], id: \.0) { number, layer in
                Text(number)
                    .font(.system(size: 92, weight: .heavy))
                    .tracking(-2.8)
                    .foregroundStyle(.white)
                    .shadow(color: Palette.acc.opacity(0.55), radius: 15)
                    .motion(pose(layer, second))
            }
            Text("READ!")
                .font(.system(size: 44, weight: .heavy))
                .tracking(1.76)
                .foregroundStyle(Palette.starGold)
                .shadow(color: Palette.acc.opacity(0.7), radius: 13)
                .motion(pose("L12", second))
        }
    }

    /// 76 pt of glass with a yellow ▶, a yellow ring and a soft glow; "TAP TO START" under it. The tap squeezes it to ×0.9 and it fades away.
    private func playButton(_ second: Double) -> some View {
        let button = pose("L13", second)
        let caption = pose("L14", second)
        return ZStack {
            Button(action: onPlay) {
                Image(systemName: "play.fill")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(Palette.acc)
                    .shadow(color: Palette.acc.opacity(0.8), radius: 6)
                    .offset(x: 2)
                    .frame(width: 76, height: 76)
                    .glassEffect(.regular.interactive(), in: .circle)
                    .overlay(Circle().strokeBorder(Palette.acc.opacity(0.8), lineWidth: 1.5))
                    .shadow(color: Palette.acc.opacity(0.4), radius: 15)
            }
            .buttonStyle(.plain)
            .motion(button)
            .accessibilityLabel(Text("Start practice"))
            .accessibilityIdentifier("practice.play")
            Text("TAP TO START")
                .font(.system(size: 10.5, weight: .semibold, design: .monospaced))
                .tracking(1.68)
                .foregroundStyle(Color.white.opacity(0.85))
                .offset(y: 54 + 8)
                .opacity(caption.opacity)
        }
    }
}
