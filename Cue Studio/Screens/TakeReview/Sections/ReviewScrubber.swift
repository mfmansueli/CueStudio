//
//  ReviewScrubber.swift
//  Cue Studio
//

import SwiftUI

/// The playhead of a review (6.3): a 3 pt track with the played part in yellow and a white knob, dragged or tapped to seek, and under it the time in
/// yellow on the left and the length in grey on the right.
struct ReviewScrubber: View {
    let progress: Double
    let duration: TimeInterval
    let onSeek: (Double) -> Void

    var body: some View {
        VStack(spacing: 7) {
            GeometryReader { proxy in
                let width = max(1, proxy.size.width)
                let x = width * min(1, max(0, progress))
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.22)).frame(height: 3)
                    Capsule().fill(Palette.acc).frame(width: x, height: 3)
                    Circle().fill(.white).frame(width: 14, height: 14).shadow(color: .black.opacity(0.4), radius: 3).offset(x: x - 7)
                }
                .frame(maxHeight: .infinity)
                .contentShape(Rectangle())
                .gesture(DragGesture(minimumDistance: 0).onChanged { onSeek(min(1, max(0, $0.location.x / width))) })
            }
            .frame(height: 24)
            HStack {
                Text(DurationText.clock(duration * progress)).foregroundStyle(Palette.accText)
                Spacer()
                Text(DurationText.clock(duration)).foregroundStyle(Palette.ink2)
            }
            .font(.system(size: 11, weight: .semibold, design: .monospaced))
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Playhead"))
        .accessibilityValue(Text("\(DurationText.clock(duration * progress)) of \(DurationText.clock(duration))"))
        .accessibilityAdjustableAction { direction in
            onSeek(min(1, max(0, progress + (direction == .increment ? 0.1 : -0.1))))
        }
        .accessibilityIdentifier("review.scrubber")
    }
}
