//
//  ClipCropLayer.swift
//  Cue Studio
//

import SwiftUI

/// Crop's box on the preview while its panel is open and the video is paused: the picked clip's whole picture shows fitted in
/// the frame (`ClipsViewModel.showingWholePicture`), what the box leaves out shaded, the box outlined with its thirds. A drag
/// inside moves it; a corner pulled resizes it from the opposite one, keeping its shape when it has one (pulling a corner of
/// Original makes a Free box). One undo step per gesture.
struct ClipCropLayer: View {
    let viewModel: QuickEditViewModel
    let size: CGSize

    /// The box when a finger first took it.
    @State private var gestureStart: ClipCrop?

    private static let whole = ClipCrop(CGRect(x: 0, y: 0, width: 1, height: 1))

    var body: some View {
        if let clip = viewModel.targetClip, !viewModel.player.isPlaying {
            let picture = pictureRect(of: clip)
            let crop = clip.crop ?? Self.whole
            let box = CGRect(
                x: picture.minX + crop.rect.minX * picture.width, y: picture.minY + crop.rect.minY * picture.height,
                width: crop.rect.width * picture.width, height: crop.rect.height * picture.height
            )
            ZStack(alignment: .topLeading) {
                Path { path in
                    path.addRect(CGRect(origin: .zero, size: size))
                    path.addRect(box)
                }
                .fill(Palette.Editor.cropShade, style: FillStyle(eoFill: true))
                .allowsHitTesting(false)
                ThirdsGrid()
                    .overlay(Rectangle().strokeBorder(Palette.Editor.overlayOutline, lineWidth: 2))
                    .shadow(color: Palette.Editor.overlayOutlineHalo, radius: 1.5)
                    .frame(width: box.width, height: box.height)
                    .contentShape(Rectangle())
                    .gesture(moveGesture(crop, picture: picture))
                    .position(x: box.midX, y: box.midY)
                    .accessibilityElement()
                    .accessibilityLabel(Text("Crop"))
                    .accessibilityHint(Text("Drag to move, or use the actions"))
                    .accessibilityActions { actions(crop, picture: picture) }
                    .accessibilityIdentifier("edit.clipCrop.box")
                ForEach(ClipCropCorner.allCases, id: \.self) { corner in
                    cornerHandle(corner, crop: crop, picture: picture, at: corner.point(of: box))
                }
            }
            .frame(width: size.width, height: size.height, alignment: .topLeading)
        }
    }

    /// Where the clip's whole picture, turned, sits fitted in the frame.
    private func pictureRect(of clip: EditSegment) -> CGRect {
        let recording = viewModel.overlays.recordingSizes[clip.sourceID] ?? size
        let picture = viewModel.clips.turnedPictureSize(ofRecording: recording)
        guard picture.width > 0, picture.height > 0 else { return CGRect(origin: .zero, size: size) }
        let scale = min(size.width / picture.width, size.height / picture.height)
        let width = picture.width * scale, height = picture.height * scale
        return CGRect(x: (size.width - width) / 2, y: (size.height - height) / 2, width: width, height: height)
    }

    // MARK: - Gestures

    private func moveGesture(_ crop: ClipCrop, picture: CGRect) -> some Gesture {
        DragGesture(minimumDistance: 2)
            .onChanged { value in
                let start = begin(crop)
                let offset = CGSize(width: value.translation.width / max(1, picture.width), height: value.translation.height / max(1, picture.height))
                viewModel.clips.setClipCrop(start.moved(by: offset))
            }
            .onEnded { _ in end() }
    }

    private func cornerHandle(_ corner: ClipCropCorner, crop: ClipCrop, picture: CGRect, at point: CGPoint) -> some View {
        let direction = corner.direction
        return Path { path in
            // An L along the box's corner, its arms inward.
            let arm: CGFloat = 16
            path.move(to: CGPoint(x: 0, y: -direction.y * arm))
            path.addLine(to: .zero)
            path.addLine(to: CGPoint(x: -direction.x * arm, y: 0))
        }
        .offset(x: Metrics.hitTarget / 2, y: Metrics.hitTarget / 2)
        .stroke(Palette.Editor.overlayOutline, style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round))
        .shadow(color: Palette.Editor.overlayOutlineHalo, radius: 1.5)
        .frame(width: Metrics.hitTarget, height: Metrics.hitTarget)
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 1)
                .onChanged { value in
                    let start = begin(crop)
                    let from = corner.point(of: start.rect)
                    let to = CGPoint(
                        x: from.x + value.translation.width / max(1, picture.width), y: from.y + value.translation.height / max(1, picture.height)
                    )
                    viewModel.clips.setClipCrop(start.pulling(corner, to: to, aspect: Double(picture.width / max(1, picture.height))))
                }
                .onEnded { _ in end() }
        )
        .position(point)
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private func actions(_ crop: ClipCrop, picture: CGRect) -> some View {
        let aspect = Double(picture.width / max(1, picture.height))
        Button("Move up") { viewModel.clips.setClipCrop(crop.moved(by: CGSize(width: 0, height: -0.05))) }
        Button("Move down") { viewModel.clips.setClipCrop(crop.moved(by: CGSize(width: 0, height: 0.05))) }
        Button("Move left") { viewModel.clips.setClipCrop(crop.moved(by: CGSize(width: -0.05, height: 0))) }
        Button("Move right") { viewModel.clips.setClipCrop(crop.moved(by: CGSize(width: 0.05, height: 0))) }
        Button("Smaller") {
            let rect = crop.rect
            let corner = CGPoint(x: rect.maxX - rect.width * 0.1, y: rect.maxY - rect.height * 0.1)
            viewModel.clips.setClipCrop(crop.pulling(.bottomTrailing, to: corner, aspect: aspect))
        }
    }

    private func begin(_ crop: ClipCrop) -> ClipCrop {
        if let gestureStart { return gestureStart }
        viewModel.player.pause()
        viewModel.beginPanelChange()
        gestureStart = crop
        return crop
    }

    private func end() {
        guard gestureStart != nil else { return }
        gestureStart = nil
        viewModel.endPanelChange()
    }
}
