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
            if let data = viewModel.coverImage, let image = UIImage(data: data) {
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
