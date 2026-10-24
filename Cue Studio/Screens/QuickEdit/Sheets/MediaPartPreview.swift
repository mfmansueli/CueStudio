//
//  MediaPartPreview.swift
//  Cue Studio
//

import AVFoundation
import SwiftUI

/// The part of a video about to go in: its frame where the part starts, and ▶ to watch the part once (it stops at its end).
struct MediaPartPreview: View {
    let url: URL
    let aspect: Double
    let start: TimeInterval
    let length: TimeInterval

    @Environment(VideoThumbnailService.self) private var thumbnails
    @State private var still: UIImage?
    @State private var player: AVPlayer?
    @State private var stop: Any?

    var body: some View {
        ZStack {
            if let player {
                PlayerView(player: player)
            } else if let still {
                Image(uiImage: still).resizable().scaledToFill()
            } else {
                Palette.surface2
            }
            Button(action: toggle) {
                Image(systemName: player == nil ? "play.fill" : "stop.fill")
                    .font(.editorGlyph(EditorGlyph.player, weight: .bold))
                    .foregroundStyle(Palette.ink)
                    .frame(width: Metrics.hitTarget, height: Metrics.hitTarget)
                    .background(Palette.Takes.durationBadge, in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(player == nil ? Text("Play this part") : Text("Stop"))
            .accessibilityIdentifier("edit.mediaPart.play")
        }
        .aspectRatio(max(0.3, min(aspect, 3)), contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: Metrics.editorCardRadius, style: .continuous))
        .frame(maxHeight: 220)
        .task(id: start) {
            // The frame where the part starts, once the window rests a moment.
            try? await Task.sleep(for: .milliseconds(120))
            guard !Task.isCancelled else { return }
            halt()
            still = await thumbnails.picture(of: url, isVideo: true, at: start, maxPixelSize: 480)
        }
        .onDisappear(perform: halt)
    }

    private func toggle() {
        guard player == nil else {
            halt()
            return
        }
        let player = AVPlayer(url: url)
        let end = CMTime(seconds: start + length, preferredTimescale: 600)
        stop = player.addBoundaryTimeObserver(forTimes: [NSValue(time: end)], queue: .main) {
            MainActor.assumeIsolated { halt() }
        }
        player.seek(to: CMTime(seconds: start, preferredTimescale: 600), toleranceBefore: .zero, toleranceAfter: .zero) { _ in
            player.play()
        }
        self.player = player
    }

    private func halt() {
        if let stop { player?.removeTimeObserver(stop) }
        stop = nil
        player?.pause()
        player = nil
    }
}
