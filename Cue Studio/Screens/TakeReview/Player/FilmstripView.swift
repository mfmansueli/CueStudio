//
//  FilmstripView.swift
//  Cue Studio
//

import SwiftUI

/// Frames across the take with a playhead. Drag to scrub.
struct FilmstripView: View {
    let take: Take
    let videoURL: URL
    /// 0...1
    let progress: Double
    let onScrub: (Double) -> Void

    private let frameCount = 7

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                FilmstripFrames(videoURL: videoURL, duration: take.edit?.sourceDuration ?? take.duration, count: frameCount)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(Color.white.opacity(0.85), lineWidth: 1.5))
                Capsule()
                    .fill(Color.white)
                    .frame(width: 3, height: proxy.size.height + 6)
                    .offset(x: max(0, min(proxy.size.width - 3, proxy.size.width * progress - 1.5)))
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        onScrub(min(1, max(0, value.location.x / max(1, proxy.size.width))))
                    }
            )
        }
        .frame(height: 36)
        .accessibilityElement()
        .accessibilityLabel(Text("Timeline"))
        .accessibilityValue(Text(DurationText.clock(take.duration * progress)))
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: onScrub(min(1, progress + 0.1))
            case .decrement: onScrub(max(0, progress - 0.1))
            @unknown default: break
            }
        }
    }
}
