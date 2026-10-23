//
//  CoverFrameStrip.swift
//  Cue Studio
//

import SwiftUI
import UIKit

/// Frames along the edit with a white box to drag onto the one wanted; the picture changes while the finger moves and the
/// frame is kept when it lifts. Each frame is read from the recording it plays (a montage's other takes and videos too).
struct CoverFrameStrip: View {
    let edit: TakeEdit
    let videoURL: URL
    /// Edited seconds the box sits on; nil when the frame isn't in the edit.
    let time: TimeInterval?
    /// The finger is on the strip at this moment (edited seconds).
    let onScrub: (TimeInterval) -> Void
    /// The finger lifted there.
    let onPick: (TimeInterval) -> Void

    @Environment(VideoThumbnailService.self) private var thumbnails
    @State private var strip: [UIImage?] = []
    @State private var dragTime: TimeInterval?

    private static let count = 10

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let total = max(0.001, edit.editedDuration)
            let shown = dragTime ?? time
            ZStack(alignment: .leading) {
                HStack(spacing: 0) {
                    ForEach(Array(strip.enumerated()), id: \.offset) { _, image in
                        Group {
                            if let image { Image(uiImage: image).resizable().scaledToFill() } else { Palette.surface2 }
                        }
                        .frame(width: width / CGFloat(max(1, strip.count)), height: 56)
                        .clipped()
                    }
                }
                if let shown {
                    let x = min(max(18, CGFloat(shown / total) * width), width - 18)
                    RoundedRectangle(cornerRadius: Metrics.clipRadius, style: .continuous)
                        .strokeBorder(Palette.Editor.overlayOutline, lineWidth: 2.5)
                        .shadow(color: Palette.Editor.overlayOutlineHalo, radius: 1.5)
                        .frame(width: 36, height: 56)
                        .position(x: x, y: 28)
                }
            }
            .frame(height: 56)
            .clipShape(RoundedRectangle(cornerRadius: Metrics.editorSegmentRadius, style: .continuous))
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { drag in
                        let time = Double(min(max(0, drag.location.x), width) / max(1, width)) * total
                        dragTime = time
                        onScrub(time)
                    }
                    .onEnded { drag in
                        dragTime = nil
                        onPick(Double(min(max(0, drag.location.x), width) / max(1, width)) * total)
                    }
            )
            .accessibilityElement()
            .accessibilityLabel(Text("Cover frame"))
            .accessibilityValue(Text(shown.map { DurationText.editor($0) } ?? ""))
            .accessibilityAdjustableAction { direction in
                let step = total / Double(Self.count)
                onPick(min(max(0, (time ?? 0) + (direction == .increment ? step : -step)), total))
            }
            .accessibilityIdentifier("cover.frameStrip")
        }
        .frame(height: 56)
        // Time runs left to right in every language (media never mirrors), like the timeline.
        .environment(\.layoutDirection, .leftToRight)
        .task(id: edit.timeline) { await load() }
    }

    private func load() async {
        let timeline = edit.timeline
        let total = edit.editedDuration
        guard total > 0 else { return }
        let urls = Dictionary(edit.sources.map { ($0.id, EditMediaFiles.url(for: $0.fileName)) }) { first, _ in first }
        let samples = (0..<Self.count).map { index -> (url: URL, time: TimeInterval) in
            let edited = (Double(index) + 0.5) / Double(Self.count) * total
            let segment = timeline.segments[timeline.segmentIndex(atEdited: edited)]
            return (segment.sourceID.flatMap { urls[$0] } ?? videoURL, timeline.sourceTime(forEdited: edited))
        }
        var images = [UIImage?](repeating: nil, count: samples.count)
        for (url, indices) in Dictionary(grouping: samples.indices, by: { samples[$0].url }) {
            let frames = await thumbnails.frames(for: url, at: indices.map { samples[$0].time }, tolerance: 0.5, maxPixelSize: 120)
            for (index, frame) in zip(indices, frames) { images[index] = frame }
        }
        strip = images
    }
}
