//
//  FilmstripFrames.swift
//  Cue Studio
//

import SwiftUI

/// Evenly spaced frames of a take side by side, the background of every timeline.
struct FilmstripFrames: View {
    let videoURL: URL
    /// Length of the recording (not of an edit), so the frames cover all of it.
    let duration: TimeInterval
    var count = 7

    @Environment(VideoThumbnailService.self) private var thumbnails
    @State private var frames: [UIImage] = []

    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<count, id: \.self) { index in
                Group {
                    if index < frames.count {
                        Image(uiImage: frames[index]).resizable().scaledToFill()
                    } else {
                        LinearGradient(colors: [Palette.thumbnailTop, Palette.thumbnailBottom], startPoint: .topLeading, endPoint: .bottomTrailing)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipped()
            }
        }
        .task(id: videoURL) {
            frames = await thumbnails.filmstrip(for: videoURL, count: count, duration: duration)
        }
        .accessibilityHidden(true)
    }
}
