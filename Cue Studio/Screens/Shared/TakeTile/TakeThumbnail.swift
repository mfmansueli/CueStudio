//
//  TakeThumbnail.swift
//  Cue Studio
//

import SwiftUI

/// Poster frame of a take, with a warm placeholder while it loads.
struct TakeThumbnail: View {
    let take: Take

    @Environment(TakeLibraryService.self) private var takes
    @Environment(VideoThumbnailService.self) private var thumbnails
    @State private var image: UIImage?

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Palette.Takes.thumbnailTop, Palette.Takes.thumbnailBottom],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .transition(.opacity)
            }
        }
        .clipped()
        .task(id: take.id) {
            image = await thumbnails.thumbnail(for: takes.videoURL(for: take))
        }
        .accessibilityHidden(true)
    }
}
