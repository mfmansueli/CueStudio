//
//  BlurEditingLayer.swift
//  Cue Studio
//

import SwiftUI

/// Blur area on the preview, while its panel is open or an area is picked and the video is paused. In the first step, the
/// faces found in the frame, numbered and dashed: a tap hides that one. Then every area showing at the playhead: a tap picks
/// one; the picked one is outlined in its real shape (yellow, or dashed orange where it may not cover what it hides, with
/// "Not tracked here"), dragged to move it (at the playhead when it moves), a corner pulled or a pinch to resize it, ✕ (its top
/// left corner) to delete it. Every change shows in the video as it's made: the box is the area itself. A face filling a selfie
/// makes an area larger than the frame: its handles and ✕ stay on the preview, at its edge, where a finger reaches them.
struct BlurEditingLayer: View {
    let viewModel: QuickEditViewModel
    let size: CGSize

    /// The picked area's rect (points) when a finger first took it: a drag and a pinch can run together, and both read it until
    /// the last ends.
    @State private var gestureStart: CGRect?
    @State private var gestures: Set<String> = []

    private var blur: BlurViewModel { viewModel.blur }

    var body: some View {
        if !viewModel.player.isPlaying {
            ZStack(alignment: .topLeading) {
                if blur.picking != nil {
                    faces
                } else if viewModel.panel == .blur || viewModel.selection?.blurID != nil {
                    ForEach(blur.shownRegions, id: \.region.id) { region, rect in
                        area(region, rect: points(rect))
                    }
                }
            }
            .frame(width: size.width, height: size.height, alignment: .topLeading)
        }
    }

    private func points(_ rect: CGRect) -> CGRect {
        CGRect(x: rect.minX * size.width, y: rect.minY * size.height, width: rect.width * size.width, height: rect.height * size.height)
    }

    // MARK: - The faces of the first step

    private var faces: some View {
        ForEach(Array(blur.pickedFaceRects.enumerated()), id: \.offset) { index, rect in
            let frame = points(rect)
            Button {
                blur.pickFace(index)
            } label: {
                RoundedRectangle(cornerRadius: Metrics.editorStripRadius, style: .continuous)
                    .strokeBorder(Palette.Editor.overlayOutline, style: StrokeStyle(lineWidth: 2, dash: [6, 4]))
                    .shadow(color: Palette.Editor.overlayOutlineHalo, radius: 1.5)
                    .frame(width: max(frame.width, 24), height: max(frame.height, 24))
                    .overlay(alignment: .topLeading) {
                        Text("\(index + 1)")
                            .font(.system(.caption, weight: .heavy))
                            .foregroundStyle(Color.black)
                            .frame(minWidth: 22, minHeight: 22)
                            .background(Color.white, in: Circle())
                            .offset(x: -11, y: -11)
                    }
                    .frame(minWidth: Metrics.hitTarget, minHeight: Metrics.hitTarget)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .position(x: frame.midX, y: frame.midY)
            .accessibilityLabel(Text("Face \(index + 1)"))
            .accessibilityHint(Text("Hides this face and tracks it"))
            .accessibilityIdentifier("edit.blur.face.\(index)")
        }
    }

    // MARK: - An area

    @ViewBuilder
    private func area(_ region: BlurRegion, rect: CGRect) -> some View {
        let isPicked = viewModel.selection == .blur(region.id)
        if isPicked {
            picked(region, rect: rect)
        } else {
            shape(region.shape)
                .stroke(Palette.Editor.overlayOutline, style: StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
                .shadow(color: Palette.Editor.overlayOutlineHalo, radius: 1.5)
                .frame(width: max(rect.width, 8), height: max(rect.height, 8))
                .contentShape(Rectangle())
                .frame(minWidth: Metrics.hitTarget, minHeight: Metrics.hitTarget)
                .onTapGesture { viewModel.selection = .blur(region.id) }
                .position(x: rect.midX, y: rect.midY)
                .accessibilityElement()
                .accessibilityLabel(Text("\(region.subject.label), \(region.style.label)"))
                .accessibilityAddTraits(.isButton)
                .accessibilityAction { viewModel.selection = .blur(region.id) }
                .accessibilityIdentifier("edit.blur.area")
        }
    }

    private func picked(_ region: BlurRegion, rect: CGRect) -> some View {
        let unchecked = blur.playheadIsUnchecked
        let tint = unchecked ? Palette.warnText : Palette.acc
        return ZStack {
            shape(region.shape)
                .stroke(tint, style: StrokeStyle(lineWidth: 2, dash: unchecked ? [6, 4] : []))
                .shadow(color: Palette.Editor.overlayOutlineHalo, radius: 1.5)
                .frame(width: rect.width, height: rect.height)
                .contentShape(Rectangle())
                .frame(minWidth: Metrics.hitTarget, minHeight: Metrics.hitTarget)
                .gesture(moveGesture(region, rect: rect))
                .simultaneousGesture(pinchGesture(region, rect: rect))
                .accessibilityElement()
                .accessibilityLabel(Text("\(region.subject.label), \(region.style.label)"))
                .accessibilityValue(unchecked ? Text("Not tracked here") : Text(""))
                .accessibilityHint(Text("Drag to move, pinch to resize, or use the actions"))
                .accessibilityAddTraits([.isButton, .isSelected])
                .accessibilityActions { actions }
                .accessibilityIdentifier("edit.blur.handle")
            // Any corner resizes around the middle: the top left one is ✕'s.
            ForEach([Corner.topTrailing, .bottomLeading, .bottomTrailing], id: \.self) { corner in
                cornerHandle(corner, region: region, rect: rect)
            }
            deleteButton(region)
                .offset(reachable(CGPoint(x: rect.minX, y: rect.minY), from: rect, margin: 14))
            if unchecked {
                Label(String(localized: "Not tracked here"), systemImage: "exclamationmark.triangle.fill")
                    .font(.system(.caption2, weight: .semibold))
                    .foregroundStyle(Palette.warnText)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Palette.Toast.fill, in: Capsule())
                    .fixedSize()
                    .offset(reachable(CGPoint(x: rect.midX, y: rect.maxY + 18), from: rect, margin: 16))
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }
        }
        .position(x: rect.midX, y: rect.midY)
    }

    @ViewBuilder
    private var actions: some View {
        Button("Move up") { blur.nudge(x: 0, y: -0.02) }
        Button("Move down") { blur.nudge(x: 0, y: 0.02) }
        Button("Move left") { blur.nudge(x: -0.02, y: 0) }
        Button("Move right") { blur.nudge(x: 0.02, y: 0) }
        Button("Bigger") { blur.resize(width: 1.1, height: 1.1) }
        Button("Smaller") { blur.resize(width: 1 / 1.1, height: 1 / 1.1) }
    }

    private func shape(_ shape: BlurShape) -> AnyShape {
        shape == .oval ? AnyShape(Ellipse()) : AnyShape(RoundedRectangle(cornerRadius: Metrics.editorHandleRadius, style: .continuous))
    }

    // MARK: - Gestures

    /// A drag moves the area: the finger's travel carried to the footage at the playhead.
    private func moveGesture(_ region: BlurRegion, rect: CGRect) -> some Gesture {
        DragGesture(minimumDistance: 3)
            .onChanged { value in
                let start = begin(rect, "move")
                // The size it has now (a pinch may be changing it meanwhile), around where the finger took it.
                let moved = CGRect(
                    x: start.midX + value.translation.width - rect.width / 2, y: start.midY + value.translation.height - rect.height / 2,
                    width: rect.width, height: rect.height
                )
                place(region, rect: moved)
            }
            .onEnded { _ in end("move") }
    }

    /// A pinch resizes it around its middle.
    private func pinchGesture(_ region: BlurRegion, rect: CGRect) -> some Gesture {
        MagnifyGesture()
            .onChanged { value in
                let start = begin(rect, "pinch")
                resize(region, from: rect, to: start.size.applying(CGAffineTransform(scaleX: value.magnification, y: value.magnification)))
            }
            .onEnded { _ in end("pinch") }
    }

    private enum Corner: CaseIterable {
        case topLeading, topTrailing, bottomLeading, bottomTrailing

        /// Which way pulling it grows the area.
        var direction: CGSize {
            switch self {
            case .topLeading: CGSize(width: -1, height: -1)
            case .topTrailing: CGSize(width: 1, height: -1)
            case .bottomLeading: CGSize(width: -1, height: 1)
            case .bottomTrailing: CGSize(width: 1, height: 1)
            }
        }
    }

    /// A corner pulled out grows the area around its middle (both sides at once), pushed in shrinks it.
    private func cornerHandle(_ corner: Corner, region: BlurRegion, rect: CGRect) -> some View {
        Circle()
            .fill(Color.white)
            .frame(width: 14, height: 14)
            .shadow(color: Palette.textShadow, radius: 2, y: 1)
            .frame(width: Metrics.hitTarget, height: Metrics.hitTarget)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 1)
                    .onChanged { value in
                        let start = begin(rect, "corner")
                        let size = CGSize(
                            width: max(24, start.width + 2 * value.translation.width * corner.direction.width),
                            height: max(24, start.height + 2 * value.translation.height * corner.direction.height)
                        )
                        resize(region, from: rect, to: size)
                    }
                    .onEnded { _ in end("corner") }
            )
            .offset(reachable(
                CGPoint(x: rect.midX + corner.direction.width * rect.width / 2, y: rect.midY + corner.direction.height * rect.height / 2),
                from: rect, margin: 12
            ))
            .accessibilityHidden(true)
    }

    /// How far from the area's middle to draw a control meant at `point`, brought onto the preview (`margin` points in).
    private func reachable(_ point: CGPoint, from rect: CGRect, margin: CGFloat) -> CGSize {
        let x = min(max(point.x, margin), max(margin, size.width - margin))
        let y = min(max(point.y, margin), max(margin, size.height - margin))
        return CGSize(width: x - rect.midX, height: y - rect.midY)
    }

    private func deleteButton(_ region: BlurRegion) -> some View {
        Button {
            blur.delete(region.id)
        } label: {
            Image(systemName: "xmark")
                .font(.editorGlyph(EditorGlyph.small, weight: .bold))
                .foregroundStyle(Color.black)
                .frame(width: 24, height: 24)
                .background(Color.white, in: Circle())
                .shadow(color: Palette.textShadow, radius: 2, y: 1)
                .frame(width: Metrics.hitTarget, height: Metrics.hitTarget)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text("Delete Blur area"))
        .accessibilityIdentifier("edit.blur.delete")
    }

    // MARK: - Changing

    /// The rect a finger took the area at: the gesture is one undo step.
    private func begin(_ rect: CGRect, _ gesture: String) -> CGRect {
        gestures.insert(gesture)
        if let gestureStart { return gestureStart }
        viewModel.player.pause()
        viewModel.beginChange()
        gestureStart = rect
        return rect
    }

    private func end(_ gesture: String) {
        gestures.remove(gesture)
        guard gestureStart != nil, gestures.isEmpty else { return }
        gestureStart = nil
        viewModel.endChange()
    }

    private func place(_ region: BlurRegion, rect: CGRect) {
        let fractions = CGRect(x: rect.minX / size.width, y: rect.minY / size.height, width: rect.width / size.width, height: rect.height / size.height)
        guard let box = blur.footageBox(for: fractions, on: region.target) else { return }
        blur.place(box)
    }

    /// The area brought from its size now (`rect`) to `target`, around its middle.
    private func resize(_ region: BlurRegion, from rect: CGRect, to target: CGSize) {
        guard rect.width > 0, rect.height > 0 else { return }
        blur.resize(width: max(24, target.width) / rect.width, height: max(24, target.height) / rect.height)
    }
}
