//
//  MediaTrimStrip.swift
//  Cue Studio
//

import SwiftUI
import UIKit

/// The part of a video laid over the take that plays: the whole file in frames, and a yellow window as long as it shows in the
/// edit, dragged to play an earlier or later part (where it shows in the edit doesn't move). Under it, how long it plays,
/// longer or shorter by a tenth or half a second.
struct MediaTrimStrip: View {
    let viewModel: QuickEditViewModel
    let media: MediaOverlay

    @Environment(VideoThumbnailService.self) private var thumbnails
    @State private var frames: [UIImage?] = []
    @State private var dragBase: TimeInterval?

    private static let count = 8

    var body: some View {
        let length = media.mediaDuration ?? 0
        let shown = viewModel.mediaBars.first { $0.id == media.id }?.span.duration ?? 0
        VStack(alignment: .leading, spacing: 8) {
            PanelRowLabel(
                label: String(localized: "Part of the video"),
                detail: String(localized: "\(DurationText.editor(media.startInFile)) to \(DurationText.editor(media.startInFile + shown)) of \(DurationText.editor(length))")
            )
            GeometryReader { proxy in
                let width = proxy.size.width
                let window = CGFloat(shown / max(0.001, length)) * width
                let x = CGFloat(media.startInFile / max(0.001, length)) * width
                ZStack(alignment: .leading) {
                    HStack(spacing: 0) {
                        ForEach(Array(frames.enumerated()), id: \.offset) { _, image in
                            Group { if let image { Image(uiImage: image).resizable().scaledToFill() } else { Palette.surface2 } }
                                .frame(width: width / CGFloat(max(1, frames.count)), height: 48)
                                .clipped()
                        }
                    }
                    .overlay { Palette.Editor.coverDim }
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .strokeBorder(Palette.acc, lineWidth: 2.5)
                        .frame(width: max(14, window), height: 48)
                        .offset(x: min(x, width - max(14, window)))
                }
                .frame(height: 48)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 2)
                        .onChanged { value in
                            if dragBase == nil {
                                viewModel.beginChange()
                                dragBase = media.startInFile
                            }
                            let moved = (dragBase ?? 0) + Double(value.translation.width / max(1, width)) * length
                            viewModel.slipMedia(media.id, toStart: moved)
                            viewModel.player.pause()
                            if let bar = viewModel.mediaBars.first(where: { $0.id == media.id }) { viewModel.player.seek(to: bar.span.start) }
                        }
                        .onEnded { _ in
                            dragBase = nil
                            viewModel.endChange()
                        }
                )
                .accessibilityElement()
                .accessibilityLabel(Text("Part of the video"))
                .accessibilityValue(Text(DurationText.editor(media.startInFile)))
                .accessibilityAdjustableAction { direction in
                    viewModel.slipMedia(media.id, toStart: media.startInFile + (direction == .increment ? 0.5 : -0.5))
                }
                .accessibilityIdentifier("edit.mediaPart")
            }
            .frame(height: 48)
            PanelStepper(
                label: String(localized: "Plays for"), value: DurationText.tenths(shown), identifier: "edit.mediaLength",
                onDecrease: { viewModel.setMediaLength(media.id, shown - 0.5) },
                onIncrease: { viewModel.setMediaLength(media.id, shown + 0.5) }
            )
        }
        .task(id: media.fileName) { await load(length: length) }
    }

    private func load(length: TimeInterval) async {
        guard length > 0 else { return }
        let times = (0..<Self.count).map { (Double($0) + 0.5) / Double(Self.count) * length }
        frames = await thumbnails.frames(for: EditMediaFiles.url(for: media.fileName), at: times, tolerance: 0.4, maxPixelSize: 100)
    }
}
