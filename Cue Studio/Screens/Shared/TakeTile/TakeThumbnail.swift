//
//  TakeThumbnail.swift
//  Cue Studio
//

import SwiftUI

/// Poster frame of a take, with a warm placeholder while it loads.
struct TakeThumbnail: View {
    let take: Take

    /// Optional: a context menu's lifted card can be drawn by the system outside the app's hierarchy, without its services (holding a
    /// video in Takes crashed on the iPhone). Without them the placeholder simply stays.
    @Environment(TakeLibraryService.self) private var takes: TakeLibraryService?
    @Environment(VideoThumbnailService.self) private var thumbnails: VideoThumbnailService?
    @State private var image: UIImage?

    var body: some View {
        PosterImage(image: image)
            .task(id: take.id) {
                guard let takes, let thumbnails else { return }
                image = await thumbnails.thumbnail(for: takes.videoURL(for: take))
            }
            .accessibilityHidden(true)
    }
}
