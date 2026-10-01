//
//  CoverPanel.swift
//  Cue Studio
//

import PhotosUI
import SwiftUI
import UIKit

/// Cover: a frame of the video or a photo; frames along the edit with a white box to drag onto
/// the one wanted (the video shows it while the finger moves, the cover once it lifts); and the
/// title on the cover, in the Cue preset. While the panel is open the preview shows the cover.
struct CoverPanel: View {
    @Bindable var viewModel: QuickEditViewModel

    @Environment(VideoThumbnailService.self) private var thumbnails
    @State private var strip: [UIImage?] = []
    @State private var pickedItem: PhotosPickerItem?
    @State private var choosesPhoto = false
    @State private var dragTime: TimeInterval?

    private static let stripCount = 10

    var body: some View {
        PanelFrame(viewModel: viewModel, panel: .cover, onReset: resetAction) {
            PanelSegmented(
                options: [
                    PanelOption(false, String(localized: "Frame from video"), key: "video"),
                    PanelOption(true, String(localized: "Photo"), key: "photo"),
                ],
                selection: viewModel.coverIsPhoto, identifier: "edit.coverSource"
            ) { photo in
                if photo { choosesPhoto = true } else { viewModel.useVideoFrameForCover() }
            }
            if !viewModel.coverIsPhoto {
                frameStrip
                PanelNote(text: String(localized: "Drag to pick the frame"))
            }
            TextField(String(localized: "Title on the cover"), text: Binding(
                get: { viewModel.edit.cover?.title ?? "" },
                set: { viewModel.setCoverTitle($0) }
            ))
            .font(.system(.callout))
            .submitLabel(.done)
            .padding(.horizontal, 14)
            .frame(height: Metrics.hitTarget)
            .background(Palette.surface2, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .accessibilityIdentifier("edit.coverTitleField")
        }
        .photosPicker(isPresented: $choosesPhoto, selection: $pickedItem, matching: .images, photoLibrary: .shared())
        .onChange(of: pickedItem) { _, item in
            guard let item else { return }
            pickedItem = nil
            Task { await viewModel.useCoverPhoto(item) }
        }
        .onAppear { viewModel.drawCover() }
        .onChange(of: viewModel.edit.cover) { _, _ in viewModel.drawCover() }
        .task(id: viewModel.edit.timeline) { await loadStrip() }
    }

    /// Reset takes the cover away.
    private var resetAction: (() -> Void)? {
        guard viewModel.edit.cover != nil else { return nil }
        return { viewModel.removeCover() }
    }

    private var frameStrip: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let total = max(0.001, viewModel.edit.editedDuration)
            let time = dragTime ?? viewModel.coverEditedTime
            let x = CGFloat(time / total) * width
            ZStack(alignment: .leading) {
                HStack(spacing: 0) {
                    ForEach(Array(strip.enumerated()), id: \.offset) { _, image in
                        Group {
                            if let image {
                                Image(uiImage: image).resizable().scaledToFill()
                            } else {
                                Palette.surface2
                            }
                        }
                        .frame(width: width / CGFloat(max(1, strip.count)), height: 64)
                        .clipped()
                    }
                }
                Palette.coverDim
                    .mask {
                        Rectangle()
                            .overlay {
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .frame(width: 40, height: 64)
                                    .position(x: min(max(20, x), width - 20), y: 32)
                                    .blendMode(.destinationOut)
                            }
                            .compositingGroup()
                    }
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(Color.white, lineWidth: 2.5)
                    .frame(width: 40, height: 64)
                    .position(x: min(max(20, x), width - 20), y: 32)
            }
            .frame(height: 64)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { drag in
                        let time = Double(min(max(0, drag.location.x), width) / max(1, width)) * total
                        dragTime = time
                        viewModel.scrubCover(toEdited: time)
                    }
                    .onEnded { drag in
                        let time = Double(min(max(0, drag.location.x), width) / max(1, width)) * total
                        dragTime = nil
                        viewModel.endCoverScrub(atEdited: time)
                    }
            )
            .accessibilityElement()
            .accessibilityLabel(Text("Cover frame"))
            .accessibilityValue(Text(DurationText.editor(time)))
            .accessibilityAdjustableAction { direction in
                let step = total / Double(Self.stripCount)
                let next = direction == .increment ? time + step : time - step
                viewModel.endCoverScrub(atEdited: next)
            }
            .accessibilityIdentifier("edit.coverStrip")
        }
        .frame(height: 64)
    }

    private func loadStrip() async {
        let samples = viewModel.coverStripSamples(count: Self.stripCount)
        var images = [UIImage?](repeating: nil, count: samples.count)
        let groups = Dictionary(grouping: samples.indices, by: { samples[$0].url })
        for (url, indices) in groups {
            let frames = await thumbnails.frames(for: url, at: indices.map { samples[$0].time }, tolerance: 0.5, maxPixelSize: 120)
            for (index, frame) in zip(indices, frames) { images[index] = frame }
        }
        strip = images
    }
}
