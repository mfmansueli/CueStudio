//
//  CoverCanvas.swift
//  Cue Studio
//

import SwiftUI
import UIKit

/// Cover Studio's canvas: the cover as it will be saved, with what can be moved on it. One finger drags the picture (on the
/// Picture step), the title or a graphic; two fingers zoom the picture, resize the title, or resize and turn a graphic; a tap
/// picks what's under it. The picked one shows its frame and handles; guides show while something sticks to the middle or a
/// third; a crop guide can show what a profile grid roughly keeps.
struct CoverCanvas: View {
    let viewModel: CoverStudioViewModel
    /// The canvas's size in points.
    let size: CGSize

    @State private var pictureBase: CoverFraming?

    var body: some View {
        ZStack(alignment: .topLeading) {
            picture
            if let guide = viewModel.cropGuide.aspect { CoverCropGuideView(aspect: guide, label: viewModel.cropGuide.label, size: size) }
            CoverGuidesView(guides: viewModel.guides, size: size)
            if let split = viewModel.composition.activeSplit {
                if viewModel.step == .image { framedHalf(split) }
                CoverDividerHandle(viewModel: viewModel, size: size)
            }
            CoverTitleHandle(viewModel: viewModel, size: size)
            ForEach(viewModel.composition.items) { item in
                CoverItemHandle(viewModel: viewModel, item: item, size: size)
            }
        }
        .frame(width: size.width, height: size.height)
        .clipShape(RoundedRectangle(cornerRadius: Metrics.editorPreviewRadius, style: .continuous))
        .coordinateSpace(name: CoverCanvas.space)
        // Touching the cover puts the keyboard away: the cover is what's being looked at.
        .simultaneousGesture(TapGesture().onEnded { Self.endTyping() })
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("cover.canvas")
    }

    static let space = "cover.canvas.space"

    /// The half the Picture step frames, outlined in yellow.
    private func framedHalf(_ split: CoverSplit) -> some View {
        let x = CGFloat(split.position) * size.width
        let rect = viewModel.editsSecondPicture
            ? CGRect(x: x, y: 0, width: size.width - x, height: size.height)
            : CGRect(x: 0, y: 0, width: x, height: size.height)
        return Rectangle()
            .strokeBorder(Palette.acc, lineWidth: 2.5)
            .frame(width: rect.width, height: rect.height)
            .offset(x: rect.minX, y: rect.minY)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }

    static func endTyping() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }

    @ViewBuilder
    private var picture: some View {
        ZStack {
            Palette.Editor.previewWell
            if let image = viewModel.rendered {
                Image(uiImage: image)
                    .resizable()
                    .interpolation(.high)
                    .frame(width: size.width, height: size.height)
                    .accessibilityLabel(Text("Cover"))
                    .accessibilityAddTraits(.isImage)
                    .accessibilityIdentifier("cover.image")
            } else if viewModel.pictureFailed {
                ContentUnavailableView(String(localized: "Can't read this picture"), systemImage: "photo.badge.exclamationmark",
                                       description: Text("Pick another frame or a photo."))
                    .foregroundStyle(Palette.ink2)
            } else {
                ProgressView().tint(Palette.ink)
            }
        }
        .frame(width: size.width, height: size.height)
        .contentShape(Rectangle())
        .onTapGesture(count: 2) {
            guard viewModel.step == .image else { return }
            viewModel.resetFraming()
        }
        .onTapGesture(coordinateSpace: .named(CoverCanvas.space)) { location in
            viewModel.tap(at: location, in: size)
        }
        .gesture(panPicture, isEnabled: viewModel.step == .image)
        .simultaneousGesture(zoomPicture, isEnabled: viewModel.step == .image)
    }

    private var panPicture: some Gesture {
        DragGesture(minimumDistance: 4)
            .onChanged { value in
                if pictureBase == nil {
                    viewModel.beginGesture()
                    pictureBase = viewModel.framing
                    selectHalf(at: value.startLocation.x)
                }
                if let base = pictureBase { viewModel.panPicture(from: base, by: value.translation, in: size) }
            }
            .onEnded { _ in
                pictureBase = nil
                viewModel.endGesture()
            }
    }

    private var zoomPicture: some Gesture {
        MagnifyGesture()
            .onChanged { value in
                if pictureBase == nil {
                    viewModel.beginGesture()
                    pictureBase = viewModel.framing
                    selectHalf(at: value.startLocation.x)
                }
                if let base = pictureBase { viewModel.zoomPicture(from: base, by: Double(value.magnification)) }
            }
            .onEnded { _ in
                pictureBase = nil
                viewModel.endGesture()
            }
    }

    /// In a before/after, the half under the finger is the one framed.
    private func selectHalf(at x: CGFloat) {
        guard let split = viewModel.composition.activeSplit else { return }
        let second = x > CGFloat(split.position) * size.width
        if viewModel.editsSecondPicture != second {
            viewModel.editsSecondPicture = second
            pictureBase = viewModel.framing
        }
    }
}
