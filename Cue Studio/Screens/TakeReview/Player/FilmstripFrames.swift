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
    /// A montage's other recordings: their stretches show their own frames.
    var sources: [ClipSource] = []

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
            guard timeline.isArranged else {
                frames = await thumbnails.frames(for: videoURL, at: times, tolerance: spacing / 4)
                return
            }
            // A montage: each frame from the recording that plays there.
            var result: [UIImage?] = []
            for position in timeline.sourcePositions(evenlyAcross: count) {
                let url = position.source
                    .flatMap { id in sources.first { $0.id == id } }
                    .map { EditMediaFiles.url(for: $0.fileName) } ?? videoURL
                result.append(await thumbnails.frames(for: url, at: [position.time], tolerance: spacing / 4).first ?? nil)
            }
            frames = result
        }
        .accessibilityHidden(true)
    }

    private struct FramesKey: Hashable {
        let url: URL
        let times: [TimeInterval]
    }
}
