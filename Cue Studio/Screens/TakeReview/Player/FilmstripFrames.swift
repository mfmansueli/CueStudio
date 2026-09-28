//
//  FilmstripFrames.swift
//  Cue Studio
//

import SwiftUI

/// Frames of a take side by side, the background of every timeline. They follow its edit: the
/// frames come from the pieces that play, so nothing cut shows up.
struct FilmstripFrames: View {
    let videoURL: URL
    /// What plays. Without an edit, the whole recording.
    let timeline: EditTimeline
    var count = 7

    @Environment(VideoThumbnailService.self) private var thumbnails
    @State private var frames: [UIImage?] = []

    private var times: [TimeInterval] { timeline.sourceTimes(evenlyAcross: count) }

    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<count, id: \.self) { index in
                FilmstripCell(image: index < frames.count ? frames[index] : nil)
            }
        }
        .task(id: FramesKey(url: videoURL, times: times)) {
            let spacing = timeline.editedDuration / Double(max(1, count))
            frames = await thumbnails.frames(for: videoURL, at: times, tolerance: spacing / 4)
        }
        .accessibilityHidden(true)
    }

    private struct FramesKey: Hashable {
        let url: URL
        let times: [TimeInterval]
    }
}
