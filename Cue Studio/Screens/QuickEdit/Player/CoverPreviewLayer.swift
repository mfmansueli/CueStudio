//
//  CoverPreviewLayer.swift
//  Cue Studio
//

import SwiftUI
import UIKit

/// The cover over the preview while the Cover tool is open: the image as it will be saved
/// (drawn on the device), with its title dragged up or down. Before a cover is chosen, a hint.
struct CoverPreviewLayer: View {
    let viewModel: QuickEditViewModel
    let size: CGSize

    @State private var titleDrag: CGFloat = 0

    var body: some View {
        ZStack {
            if viewModel.coverPreview == .grid, let data = viewModel.coverImage, let image = UIImage(data: data) {
                gridPreview(image)
            } else if let data = viewModel.coverImage, let image = UIImage(data: data) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: size.width, height: size.height)
                    .clipped()
                    .overlay(alignment: .topLeading) { titleGuide }
                    .gesture(titleGesture)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(Text("Cover"))
                    .accessibilityHint(Text("Drag up or down to move the title"))
                    .accessibilityIdentifier("edit.coverPreview")
            }
            if viewModel.isDrawingCover {
                ProgressView().tint(Palette.ink)
            }
        }
        .frame(width: size.width, height: size.height)
        .allowsHitTesting(viewModel.coverImage != nil)
    }

    /// The cover among the series on a profile: a 3 × 3 grid of 3:4 tiles, this cover in the middle
    /// ringed in yellow and the others placeholders numbered in the cover's typeface.
    private func gridPreview(_ cover: UIImage) -> some View {
        let spacing: CGFloat = 2
        let tileWidth = min((size.width - spacing * 2) / 3, (size.height - spacing * 2) / 3 * 3 / 4)
        let tile = CGSize(width: tileWidth, height: tileWidth * 4 / 3)
        let design = viewModel.coverDesign
        return LazyVGrid(columns: Array(repeating: GridItem(.fixed(tile.width), spacing: spacing), count: 3), spacing: spacing) {
            ForEach(0..<9, id: \.self) { index in
                if index == 4 {
                    Image(uiImage: cover)
                        .resizable()
                        .scaledToFill()
                        .frame(width: tile.width, height: tile.height)
                        .clipped()
                        .overlay(Rectangle().strokeBorder(Palette.acc, lineWidth: 2))
                } else {
                    Text("EP " + String(format: "%02d", max(1, design.episode + 4 - index)))
                        .font(Font(CoverDesignRenderer.words(design.font, size: tile.width * 0.2)))
                        .foregroundStyle(Palette.ink2)
                        .frame(width: tile.width, height: tile.height)
                        .background(Palette.surface2)
                }
            }
        }
        .frame(width: size.width, height: size.height)
        .background(Color.black)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Profile grid"))
        .accessibilityIdentifier("edit.coverGrid")
    }

    /// A line where the title will land while it's dragged.
    @ViewBuilder
    private var titleGuide: some View {
        if titleDrag != 0, let cover = viewModel.edit.cover {
            Rectangle()
                .fill(Palette.acc)
                .frame(width: size.width, height: 2)
                .offset(y: CGFloat(cover.titleY) * size.height + titleDrag)
                .allowsHitTesting(false)
        }
    }

    private var titleGesture: some Gesture {
        DragGesture(minimumDistance: 3)
            .onChanged { value in titleDrag = value.translation.height }
            .onEnded { value in
                if let cover = viewModel.edit.cover {
                    viewModel.setCoverTitlePosition(cover.titleY + Double(value.translation.height / max(1, size.height)))
                }
                titleDrag = 0
            }
    }
}
