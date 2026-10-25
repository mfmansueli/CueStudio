//
//  MediaPartStrip.swift
//  Cue Studio
//

import SwiftUI
import UIKit

/// A video's frames with a yellow window over the part that goes in: drag the window to take an earlier or later part; when
/// the length may change, drag its ends to make it longer or shorter (a slot to fill keeps its length). What's left out is
/// dimmed, so how much of the video is used shows at a glance. Time runs left to right in every language.
struct MediaPartStrip: View {
    let url: URL
    let fileLength: TimeInterval
    @Binding var start: TimeInterval
    @Binding var length: TimeInterval
    /// How long the part can be; nil keeps `length` as it is.
    var lengthRange: ClosedRange<TimeInterval>?
    var identifier = "edit.mediaPartStrip"

    @Environment(VideoThumbnailService.self) private var thumbnails
    @State private var frames: [UIImage?] = []
    @State private var drag: (target: Target, start: TimeInterval, length: TimeInterval)?

    private enum Target { case window, leading, trailing }

    private static let count = 10
    private static let height: CGFloat = 52
    /// Where a finger takes an end of the window, inside and outside it.
    private static let edgeReach: CGFloat = 22

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let scale = width / CGFloat(max(0.001, fileLength))
            let x = CGFloat(start) * scale
            let window = max(16, CGFloat(length) * scale)
            ZStack(alignment: .leading) {
                HStack(spacing: 0) {
                    ForEach(Array(frames.enumerated()), id: \.offset) { _, image in
                        Group { if let image { Image(uiImage: image).resizable().scaledToFill() } else { Palette.surface2 } }
                            .frame(width: width / CGFloat(max(1, frames.count)), height: Self.height)
                            .clipped()
                    }
                }
                // What's left out, dimmed.
                Palette.Editor.coverDim.frame(width: max(0, x), height: Self.height)
                Palette.Editor.coverDim.frame(width: max(0, width - x - window), height: Self.height).offset(x: x + window)
                RoundedRectangle(cornerRadius: Metrics.editorThumbnailRadius, style: .continuous)
                    .strokeBorder(Palette.acc, lineWidth: 3)
                    .frame(width: window, height: Self.height)
                    .overlay(alignment: .leading) { if lengthRange != nil { grip } }
                    .overlay(alignment: .trailing) { if lengthRange != nil { grip } }
                    .offset(x: min(x, width - window))
            }
            .frame(height: Self.height)
            .clipShape(RoundedRectangle(cornerRadius: Metrics.editorStripRadius, style: .continuous))
            .contentShape(Rectangle())
            .gesture(dragGesture(width: width, scale: scale))
        }
        .frame(height: Self.height)
        .environment(\.layoutDirection, .leftToRight)
        .accessibilityElement()
        .accessibilityLabel(Text("Part of the video"))
        .accessibilityValue(Text(verbatim: DurationText.editorRange(start, start + length)))
        .accessibilityAdjustableAction { direction in
            move(to: start + (direction == .increment ? 0.5 : -0.5))
        }
        .accessibilityIdentifier(identifier)
        .task(id: url) { await load() }
    }

    /// The thicker yellow edge a finger takes to change the length.
    private var grip: some View {
        Capsule().fill(Palette.acc).frame(width: 5, height: 22).padding(.horizontal, 2)
    }

    private func dragGesture(width: CGFloat, scale: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 2)
            .onChanged { value in
                let moved = TimeInterval(value.translation.width / max(0.001, scale))
                if drag == nil {
                    let x = CGFloat(start) * scale
                    let window = max(16, CGFloat(length) * scale)
                    let at = value.startLocation.x
                    let target: Target = if lengthRange != nil, abs(at - x) <= Self.edgeReach {
                        .leading
                    } else if lengthRange != nil, abs(at - (x + window)) <= Self.edgeReach {
                        .trailing
                    } else {
                        .window
                    }
                    drag = (target, start, length)
                }
                guard let drag else { return }
                switch drag.target {
                case .window: move(to: drag.start + moved)
                case .leading: resize(start: drag.start + moved, end: drag.start + drag.length)
                case .trailing: resize(start: drag.start, end: drag.start + drag.length + moved)
                }
            }
            .onEnded { _ in drag = nil }
    }

    /// The window to `wanted`, keeping its length, inside the video.
    private func move(to wanted: TimeInterval) {
        let clamped = min(max(0, wanted), max(0, fileLength - length))
        if clamped == 0 || clamped == fileLength - length, abs(clamped - start) > 0.01 { Haptics.snap() }
        start = clamped
    }

    /// The window from `from` to `to`, as long as the range allows, inside the video.
    private func resize(start from: TimeInterval, end to: TimeInterval) {
        guard let range = lengthRange else { return }
        var lower = max(0, from)
        var upper = min(fileLength, to)
        if upper - lower < range.lowerBound {
            if from != start { lower = upper - range.lowerBound } else { upper = lower + range.lowerBound }
        }
        if upper - lower > range.upperBound {
            if from != start { lower = upper - range.upperBound } else { upper = lower + range.upperBound }
        }
        start = max(0, lower)
        length = max(range.lowerBound, min(upper, fileLength) - start)
    }

    private func load() async {
        guard fileLength > 0 else { return }
        let times = (0..<Self.count).map { (Double($0) + 0.5) / Double(Self.count) * fileLength }
        frames = await thumbnails.frames(for: url, at: times, tolerance: 0.4, maxPixelSize: 120)
    }
}
