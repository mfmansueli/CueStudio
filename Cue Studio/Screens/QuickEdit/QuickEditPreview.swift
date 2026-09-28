//
//  QuickEditPreview.swift
//  Cue Studio
//

import AVFoundation
import SwiftUI

/// The edited take playing live: rebuilt a moment after each change, in its frame. With the Crop
/// tool, dragging moves the crop.
struct QuickEditPreview: View {
    let viewModel: QuickEditViewModel
    let size: CGSize

    @Environment(TakeEditService.self) private var editing
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var player = AVPlayer()
    @State private var dragStartOffset: Double?

    var body: some View {
        PlayerView(player: player)
            .frame(width: size.width, height: size.height)
            .background(Palette.previewWell)
            .clipShape(RoundedRectangle(cornerRadius: Metrics.tileRadius, style: .continuous))
            .overlay {
                if viewModel.tool == .crop {
                    ThirdsGrid()
                        .clipShape(RoundedRectangle(cornerRadius: Metrics.tileRadius, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: Metrics.tileRadius, style: .continuous).strokeBorder(Color.white.opacity(0.8), lineWidth: 2))
                        .allowsHitTesting(false)
                }
            }
            .gesture(cropDrag, isEnabled: viewModel.tool == .crop)
            .onTapGesture {
                player.timeControlStatus == .paused ? player.play() : player.pause()
            }
            .animation(reduceMotion ? nil : .smooth(duration: 0.3), value: size)
            .task(id: viewModel.edit) {
                // Waits for the sliders to settle before rebuilding.
                try? await Task.sleep(for: .milliseconds(300))
                guard !Task.isCancelled else { return }
                await rebuild()
            }
            .onDisappear { player.pause() }
            .accessibilityLabel(Text("Preview"))
            .accessibilityHint(Text("Tap to play or pause"))
    }

    private var cropDrag: some Gesture {
        DragGesture()
            .onChanged { value in
                let start = dragStartOffset ?? viewModel.edit.cropOffset
                dragStartOffset = start
                let wide = viewModel.edit.aspect.widthOverHeight > 9.0 / 16.0
                let travel = wide ? value.translation.width / max(1, size.width) : value.translation.height / max(1, size.height)
                viewModel.edit.cropOffset = min(1, max(-1, start - Double(travel) * 2))
            }
            .onEnded { _ in dragStartOffset = nil }
    }

    private func rebuild() async {
        guard let item = try? await editing.previewItem(forVideoAt: viewModel.videoURL, edit: viewModel.edit) else { return }
        await player.replaceCurrentItemKeepingTime(with: item)
    }
}
