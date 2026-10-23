//
//  ClipOrderThumbnail.swift
//  Cue Studio
//

import SwiftUI

/// A clip's frame in Reorder: the moment in its middle, read once and kept by `VideoThumbnailService`.
struct ClipOrderThumbnail: View {
    let url: URL
    let time: TimeInterval
    let thumbnails: VideoThumbnailService
    @State private var image: UIImage?

    var body: some View {
        ZStack {
            Palette.Editor.previewWell
            if let image { Image(uiImage: image).resizable().scaledToFill() }
        }
        .frame(width: 36, height: 64)
        .clipShape(RoundedRectangle(cornerRadius: Metrics.editorThumbnailRadius, style: .continuous))
        .accessibilityHidden(true)
        .task(id: "\(url.path(percentEncoded: false))-\(time)") {
            image = await thumbnails.frames(for: url, at: [time], tolerance: 0.5).first ?? nil
        }
    }
}
