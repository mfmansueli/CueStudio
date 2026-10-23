//
//  ReviewScrubber.swift
//  Cue Studio
//

import SwiftUI

/// The playhead of a review (6.3): a 3 pt track with the played part in yellow and a white knob, dragged or tapped to seek, and under it the time in
/// yellow on the left and the length in grey on the right. Held, the knob grows and a bubble over it says the time; a tick is felt at each second
/// crossed, and a firmer one at the start and the end (owner's refinement, 22/10/2026).
struct ReviewScrubber: View {
    let progress: Double
    let duration: TimeInterval
    let onSeek: (Double) -> Void

    @State private var isDragging = false
    /// The whole second the drag last crossed, for its tick.
    @State private var lastSecond: Int?

    var body: some View {
        VStack(spacing: 7) {
            GeometryReader { proxy in
                let width = max(1, proxy.size.width)
                let x = width * min(1, max(0, progress))
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.22)).frame(height: 3)
                    Capsule().fill(Palette.acc).frame(width: x, height: 3)
                    Circle()
                        .fill(.white)
                        .frame(width: isDragging ? 24 : 14, height: isDragging ? 24 : 14)
                        .shadow(color: .black.opacity(0.4), radius: 3)
                        .offset(x: x - (isDragging ? 12 : 7))
                    bubble.offset(x: min(max(0, x - 26), width - 52), y: -30)
                }
                .frame(maxHeight: .infinity)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { drag in
                            if !isDragging { withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) { isDragging = true } }
                            let fraction = min(1, max(0, drag.location.x / width))
                            feel(fraction)
                            onSeek(fraction)
                        }
                        .onEnded { _ in
                            lastSecond = nil
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { isDragging = false }
                        }
                )
            }
            .frame(height: 24)
            HStack {
                Text(DurationText.clock(duration * progress)).foregroundStyle(Palette.accText)
                Spacer()
                Text(DurationText.clock(duration)).foregroundStyle(Palette.ink2)
            }
            .monoFont(size: 11, weight: .semibold)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Playhead"))
        .accessibilityValue(Text("\(DurationText.clock(duration * progress)) of \(DurationText.clock(duration))"))
        .accessibilityAdjustableAction { direction in
            onSeek(min(1, max(0, progress + (direction == .increment ? 0.1 : -0.1))))
        }
        .accessibilityIdentifier("review.scrubber")
    }

    /// The time over the knob while it is held.
    private var bubble: some View {
        Text(DurationText.clock(duration * progress))
            .monoFont(size: 12, weight: .bold)
            .foregroundStyle(Color.black)
            .frame(width: 52, height: 24)
            .background(Color.white, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .opacity(isDragging ? 1 : 0)
            .scaleEffect(isDragging ? 1 : 0.7, anchor: .bottom)
            .allowsHitTesting(false)
    }

    /// A tick at each whole second crossed; a firmer tap on reaching the start or the end.
    private func feel(_ fraction: Double) {
        let second = Int((duration * fraction).rounded(.down))
        defer { lastSecond = second }
        guard let lastSecond, second != lastSecond else { return }
        if fraction <= 0 || fraction >= 1 { Haptics.rigid() } else { Haptics.selection() }
    }
}
