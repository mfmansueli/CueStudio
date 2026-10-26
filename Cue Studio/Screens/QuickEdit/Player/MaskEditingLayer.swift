//
//  MaskEditingLayer.swift
//  Cue Studio
//

import SwiftUI

/// The picked photo's or video's mask on the preview, while Mask is open and the video is paused: its real outline (yellow;
/// dashed further out where a soft edge fades), and handles that say what they do. Inside, a drag moves the mask over a still
/// picture (Mask) or the picture under a still mask (Picture, the rest of the picture shown faintly around it); a pinch
/// resizes the mask or brings the picture closer; two fingers turn the mask. The side handles change its width and height, ↻
/// turns it, the yellow arrow below pulls its edge softer, the dot in a rectangle's corner rounds its corners, a band's handle
/// sets its thickness, and a line's arrow points to the side that shows. On a small mask the handles move out around it, a
/// finger apart, a thin line leading each tab back to its side (`HandleSpread`). Every change shows in the video as it's made,
/// and a gesture is one undo step.
struct MaskEditingLayer: View {
    let viewModel: QuickEditViewModel
    let size: CGSize

    @Environment(VideoThumbnailService.self) private var thumbnails
    /// The mask as a finger took it (and the picture's last pinch and travel), for the gestures under way: a drag, a pinch and a
    /// turn can run together, and all read the mask as it was when the first began, until the last ends.
    @State private var start: MaskPlacement?
    @State private var gestures: Set<String> = []
    @State private var lastTranslation: CGSize = .zero
    @State private var lastMagnification: CGFloat = 1
    /// The picture under the mask, drawn faintly around it in Picture.
    @State private var ghost: (id: UUID, image: UIImage)?

    private var overlays: OverlaysViewModel { viewModel.overlays }

    /// The mask on the preview: its middle, size and turn in points, and the place it lives on.
    private struct Geometry {
        let placement: MediaPicturePlacement
        let center: CGPoint
        let width: CGFloat
        let height: CGFloat
        let degrees: Double
        /// How far its soft edge spreads, in points.
        let feather: CGFloat
        /// The place's shorter side, in points as shown.
        let short: CGFloat
        /// Points as shown per point of the place.
        let scale: CGFloat
        let rect: CGRect

        /// A point `x`, `y` along the mask's own axes from its middle, turned onto the preview.
        func point(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            let angle = degrees * .pi / 180
            return CGPoint(x: center.x + x * cos(angle) - y * sin(angle), y: center.y + x * sin(angle) + y * cos(angle))
        }

        /// A way `x`, `y` along the mask's own axes, turned onto the preview.
        func direction(_ x: CGFloat, _ y: CGFloat) -> CGVector {
            let angle = degrees * .pi / 180
            return CGVector(dx: x * cos(angle) - y * sin(angle), dy: x * sin(angle) + y * cos(angle))
        }

        /// A finger's travel on the preview, along the mask's own axes.
        func local(_ translation: CGSize) -> CGSize {
            let angle = degrees * .pi / 180
            return CGSize(
                width: translation.width * cos(angle) + translation.height * sin(angle),
                height: -translation.width * sin(angle) + translation.height * cos(angle)
            )
        }
    }

    var body: some View {
        // ◐ shows the picture as it is without the mask: nothing drawn over it then.
        if viewModel.panel == .mask, !viewModel.player.isPlaying, !overlays.comparesWithoutMask, let media = viewModel.selectedMedia, let mask = media.mask,
           overlays.localTime(of: .media(media.id)) != nil, let placementNow = overlays.maskPlacementAtPlayhead(of: media) {
            let geometry = geometry(media, placement: placementNow)
            ZStack(alignment: .topLeading) {
                if overlays.maskDragTarget == .picture { ghostPicture(media, geometry: geometry) }
                dragArea(media, geometry: geometry)
                outline(mask, placement: placementNow, geometry: geometry)
                if overlays.maskDragTarget == .mask { handles(mask, placement: placementNow, geometry: geometry) }
            }
            .frame(width: size.width, height: size.height, alignment: .topLeading)
            .coordinateSpace(name: Self.space)
            .task(id: media.id) { await loadGhost(media) }
        }
    }

    private func geometry(_ media: MediaOverlay, placement mask: MaskPlacement) -> Geometry {
        let motion = media.keyframes?.isEmpty == false || media.animation != nil ? overlays.motionState(of: .media(media.id)) : nil
        let placement = MediaPicturePlacement(media: media, pictureSize: CGSize(width: media.aspect * 1000, height: 1000), frameSize: size, motion: motion)
        let center = placement.framePoint(forPlace: mask.center)
        let scale = CGFloat(placement.scale)
        let rect = placement.rect
        let short = min(rect.width, rect.height) * scale
        return Geometry(
            placement: placement, center: CGPoint(x: center.x * size.width, y: center.y * size.height),
            width: CGFloat(mask.width) * rect.width * scale, height: CGFloat(mask.height) * rect.height * scale, degrees: mask.rotation,
            feather: CGFloat(mask.feather) * MaskDrawing.featherShare * short, short: short, scale: scale, rect: rect
        )
    }

    // MARK: - Drawing

    @ViewBuilder
    private func outline(_ mask: MediaMask, placement: MaskPlacement, geometry: Geometry) -> some View {
        let tint = overlays.maskDragTarget == .mask ? Palette.acc : Palette.Editor.overlayOutline
        let dash: [CGFloat] = overlays.maskDragTarget == .mask ? [] : [5, 4]
        Group {
            switch mask.shape {
            case .rectangle:
                let radius = CGFloat(placement.corners) * min(geometry.width, geometry.height) / 2
                RoundedRectangle(cornerRadius: radius, style: .circular).stroke(tint, style: StrokeStyle(lineWidth: 2, dash: dash))
                    .frame(width: geometry.width, height: geometry.height)
                if geometry.feather >= 2 {
                    RoundedRectangle(cornerRadius: radius + geometry.feather / 2, style: .circular)
                        .stroke(tint.opacity(0.6), style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
                        .frame(width: geometry.width + geometry.feather, height: geometry.height + geometry.feather)
                }
            case .circle:
                Ellipse().stroke(tint, style: StrokeStyle(lineWidth: 2, dash: dash))
                    .frame(width: geometry.width, height: geometry.height)
                if geometry.feather >= 2 {
                    Ellipse().stroke(tint.opacity(0.6), style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
                        .frame(width: geometry.width + geometry.feather, height: geometry.height + geometry.feather)
                }
            case .line:
                Rectangle().fill(tint).frame(width: (size.width + size.height) * 2, height: 2)
            case .band:
                let thickness = CGFloat(placement.height) * geometry.rect.height * geometry.scale
                VStack(spacing: max(0, thickness - 4)) {
                    Rectangle().fill(tint).frame(height: 2)
                    Rectangle().fill(tint).frame(height: 2)
                }
                .frame(width: (size.width + size.height) * 2)
            }
        }
        .shadow(color: Palette.Editor.overlayOutlineHalo, radius: 1.5)
        .rotationEffect(.degrees(geometry.degrees))
        .position(geometry.center)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    /// Picture: the whole picture faintly around the mask, so what a drag brings in is seen.
    @ViewBuilder
    private func ghostPicture(_ media: MediaOverlay, geometry: Geometry) -> some View {
        if let ghost, ghost.id == media.id {
            let frame = geometry.placement.frameRect(forPicture: NormalizedBox(x: 0, y: 0, width: 1, height: 1))
            Image(uiImage: ghost.image)
                .resizable()
                .frame(width: frame.width * size.width, height: frame.height * size.height)
                .opacity(0.3)
                .position(x: frame.midX * size.width, y: frame.midY * size.height)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        }
    }

    // MARK: - Handles

    /// Where each handle sits (`HandleSpread`): at the side, past the edge or in the corner it changes, moved out along its way
    /// on a small mask so none covers another or the mask's middle, and kept on the preview. A side with no room for both its
    /// tabs keeps one (the two pull together anyway), on the other side when its own has no room on the preview.
    private func handleSpots(_ mask: MediaMask, placement: MaskPlacement, geometry: Geometry) -> [String: HandleSpread.Spot] {
        let reach: CGFloat = 26
        let room = Metrics.hitTarget * 0.7
        var handles: [HandleSpread.Handle] = []
        switch mask.shape {
        case .rectangle, .circle:
            let halfWidth = geometry.width / 2, halfHeight = geometry.height / 2
            let left = (anchor: geometry.point(-halfWidth, 0), outward: geometry.direction(-1, 0))
            let top = (anchor: geometry.point(0, -halfHeight), outward: geometry.direction(0, -1))
            let bothWide = halfWidth >= room, bothTall = halfHeight >= room
            handles.append(HandleSpread.Handle(
                "right", at: geometry.point(halfWidth, 0), outward: geometry.direction(1, 0), otherSide: bothWide ? nil : left
            ))
            handles.append(HandleSpread.Handle(
                "bottom", at: geometry.point(0, halfHeight), outward: geometry.direction(0, 1), otherSide: bothTall ? nil : top
            ))
            if bothWide { handles.append(HandleSpread.Handle("left", at: left.anchor, outward: left.outward)) }
            if bothTall { handles.append(HandleSpread.Handle("top", at: top.anchor, outward: top.outward)) }
            handles.append(HandleSpread.Handle("turn", at: geometry.point(0, -halfHeight - reach), outward: geometry.direction(0, -1)))
            handles.append(HandleSpread.Handle(
                "feather", at: geometry.point(0, halfHeight + reach + geometry.feather / 2), outward: geometry.direction(0, 1)
            ))
            if mask.shape.hasCorners {
                let radius = CGFloat(placement.corners) * min(geometry.width, geometry.height) / 2
                let inset = min(max(12, radius * 0.6), min(halfWidth, halfHeight))
                handles.append(HandleSpread.Handle(
                    "corners", at: geometry.point(-halfWidth + inset, -halfHeight + inset), outward: geometry.direction(-1, -1)
                ))
            }
        case .line:
            handles.append(HandleSpread.Handle("turn", at: geometry.point(min(90, geometry.short / 2), 0), outward: geometry.direction(1, 0)))
            handles.append(HandleSpread.Handle("feather", at: geometry.point(0, reach + geometry.feather / 2), outward: geometry.direction(0, 1)))
        case .band:
            let thickness = CGFloat(placement.height) * geometry.rect.height * geometry.scale
            handles.append(HandleSpread.Handle("thickness", at: geometry.point(0, thickness / 2), outward: geometry.direction(0, 1)))
            handles.append(HandleSpread.Handle("turn", at: geometry.point(min(90, geometry.short / 2), 0), outward: geometry.direction(1, 0)))
            handles.append(HandleSpread.Handle(
                "feather", at: geometry.point(0, thickness / 2 + reach + geometry.feather / 2), outward: geometry.direction(0, 1)
            ))
        }
        return HandleSpread.place(handles, around: geometry.center, in: CGRect(origin: .zero, size: size), spacing: Metrics.hitTarget, margin: 12)
    }

    @ViewBuilder
    private func handles(_ mask: MediaMask, placement: MaskPlacement, geometry: Geometry) -> some View {
        let spots = handleSpots(mask, placement: placement, geometry: geometry)
        let places = spots.mapValues(\.point)
        leaders(spots.filter { Self.tabs.contains($0.key) })
        switch mask.shape {
        case .rectangle, .circle:
            // A tab moved to the other side grows the mask when pulled out of that side.
            if let point = places["right"] { sideHandle(point, axis: .width, sign: side(point, 1, 0, geometry), geometry: geometry, id: "right") }
            if let point = places["left"] { sideHandle(point, axis: .width, sign: -1, geometry: geometry, id: "left") }
            if let point = places["bottom"] { sideHandle(point, axis: .height, sign: side(point, 0, 1, geometry), geometry: geometry, id: "bottom") }
            if let point = places["top"] { sideHandle(point, axis: .height, sign: -1, geometry: geometry, id: "top") }
            if let point = places["turn"] { turnHandle(point, geometry: geometry) }
            if let point = places["feather"] { featherHandle(point, geometry: geometry) }
            if let point = places["corners"] { cornerHandle(point, geometry: geometry) }
        case .line:
            if let point = places["turn"] { turnHandle(point, geometry: geometry) }
            if let point = places["feather"] { featherHandle(point, geometry: geometry) }
            // The side that shows: above the line, below once inverted.
            Image(systemName: mask.inverted ? "arrow.down" : "arrow.up")
                .font(.editorGlyph(EditorGlyph.small, weight: .bold))
                .foregroundStyle(Palette.accInk)
                .frame(width: 22, height: 22)
                .background(Palette.acc, in: Circle())
                .rotationEffect(.degrees(geometry.degrees))
                .position(geometry.point(-min(60, geometry.short / 3), mask.inverted ? 18 : -18))
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        case .band:
            if let point = places["thickness"] { sideHandle(point, axis: .thickness, geometry: geometry, id: "thickness") }
            if let point = places["turn"] { turnHandle(point, geometry: geometry) }
            if let point = places["feather"] { featherHandle(point, geometry: geometry) }
        }
    }

    /// 1 when `point` is on the side of the mask the way `x`, `y` (its own axes) points to, -1 on the other.
    private func side(_ point: CGPoint, _ x: CGFloat, _ y: CGFloat, _ geometry: Geometry) -> CGFloat {
        let way = geometry.direction(x, y)
        return (point.x - geometry.center.x) * way.dx + (point.y - geometry.center.y) * way.dy < 0 ? -1 : 1
    }

    /// The handles that belong to a point of the outline (a side, a corner): moved out, a line leads back to it.
    private static let tabs: Set<String> = ["right", "left", "bottom", "top", "thickness", "corners"]

    /// A thin line from each handle moved out of a small mask to the point of the outline it changes.
    private func leaders(_ spots: [String: HandleSpread.Spot]) -> some View {
        Path { path in
            for spot in spots.values where HandleSpread.distance(spot.anchor, spot.point) > 8 {
                path.move(to: spot.anchor)
                path.addLine(to: spot.point)
            }
        }
        .stroke(Palette.Editor.overlayOutline, style: StrokeStyle(lineWidth: 1, lineCap: .round))
        .shadow(color: Palette.Editor.overlayOutlineHalo, radius: 1)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private enum Axis {
        case width, height, thickness
    }

    /// A white tab on a side: pulled out, that side and the opposite grow together.
    private func sideHandle(_ point: CGPoint, axis: Axis, sign: CGFloat = 1, geometry: Geometry, id: String) -> some View {
        Capsule()
            .fill(Color.white)
            .frame(width: axis == .width ? 6 : 18, height: axis == .width ? 18 : 6)
            .shadow(color: Palette.textShadow, radius: 2, y: 1)
            .rotationEffect(.degrees(geometry.degrees))
            .frame(width: Metrics.hitTarget, height: Metrics.hitTarget)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 1)
                    .onChanged { value in
                        let from = begin("side-\(id)")
                        let local = geometry.local(value.translation)
                        overlays.updateMaskPlacement { placement in
                            let place = geometry.rect.size, scale = max(0.001, geometry.scale)
                            switch axis {
                            case .width:
                                placement.width = from.width + Double(2 * local.width * sign / (place.width * scale))
                            case .height, .thickness:
                                placement.height = from.height + Double(2 * local.height * sign / (place.height * scale))
                            }
                        }
                    }
                    .onEnded { _ in end("side-\(id)") }
            )
            .position(point)
            .accessibilityHidden(true)
            .accessibilityIdentifier("edit.mask.handle.\(id)")
    }

    /// ↻ over the mask: dragged round its middle, it turns the mask.
    private func turnHandle(_ point: CGPoint, geometry: Geometry) -> some View {
        Image(systemName: "arrow.clockwise")
            .font(.editorGlyph(EditorGlyph.small, weight: .bold))
            .foregroundStyle(Color.black)
            .frame(width: 24, height: 24)
            .background(Color.white, in: Circle())
            .shadow(color: Palette.textShadow, radius: 2, y: 1)
            .frame(width: Metrics.hitTarget, height: Metrics.hitTarget)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 1, coordinateSpace: .named(Self.space))
                    .onChanged { value in
                        let from = begin("turn")
                        let before = atan2(value.startLocation.y - geometry.center.y, value.startLocation.x - geometry.center.x)
                        let now = atan2(value.location.y - geometry.center.y, value.location.x - geometry.center.x)
                        var degrees = from.rotation + Double(now - before) * 180 / .pi
                        // Sticks to a straight angle.
                        let nearest = (degrees / 90).rounded() * 90
                        if abs(degrees - nearest) < 3 { degrees = nearest }
                        overlays.updateMaskPlacement { $0.rotation = degrees }
                    }
                    .onEnded { _ in end("turn") }
            )
            .position(point)
            .accessibilityHidden(true)
            .accessibilityIdentifier("edit.mask.handle.turn")
    }

    /// The yellow arrow under the mask: pulled away, the edge gets softer.
    private func featherHandle(_ point: CGPoint, geometry: Geometry) -> some View {
        Image(systemName: "arrow.down")
            .font(.editorGlyph(EditorGlyph.small, weight: .bold))
            .foregroundStyle(Palette.accInk)
            .frame(width: 24, height: 24)
            .background(Palette.acc, in: Circle())
            .rotationEffect(.degrees(geometry.degrees))
            .frame(width: Metrics.hitTarget, height: Metrics.hitTarget)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 1)
                    .onChanged { value in
                        let from = begin("feather")
                        let local = geometry.local(value.translation)
                        let most = MaskDrawing.featherShare * max(1, geometry.short)
                        overlays.updateMaskPlacement { $0.feather = from.feather + Double(local.height * 2 / most) }
                    }
                    .onEnded { _ in end("feather") }
            )
            .position(point)
            .accessibilityHidden(true)
            .accessibilityIdentifier("edit.mask.handle.feather")
    }

    /// The dot inside a rectangle's corner: pulled in, the corners get rounder.
    private func cornerHandle(_ point: CGPoint, geometry: Geometry) -> some View {
        Circle()
            .fill(Palette.acc)
            .frame(width: 12, height: 12)
            .overlay(Circle().stroke(Color.black.opacity(0.6), lineWidth: 1))
            .frame(width: Metrics.hitTarget, height: Metrics.hitTarget)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 1)
                    .onChanged { value in
                        let from = begin("corners")
                        let local = geometry.local(value.translation)
                        let half = max(1, min(geometry.width, geometry.height) / 2)
                        overlays.updateMaskPlacement { $0.corners = from.corners + Double((local.width + local.height) / 2 / half) }
                    }
                    .onEnded { _ in end("corners") }
            )
            .position(point)
            .accessibilityHidden(true)
            .accessibilityIdentifier("edit.mask.handle.corners")
    }

    // MARK: - The drag inside

    private static let space = "edit.mask.space"

    /// The media's place: a drag moves the mask (or the picture), a pinch sizes it (or zooms the picture), two fingers turn
    /// the mask.
    private func dragArea(_ media: MediaOverlay, geometry: Geometry) -> some View {
        let place = geometry.placement.placeOnFrame
        let placed = CGRect(x: place.minX * size.width, y: place.minY * size.height, width: place.width * size.width, height: place.height * size.height)
            .intersection(CGRect(origin: .zero, size: size))
        // A place moved off the frame by its keyframes: the whole preview takes the gestures.
        let frame = placed.isNull || placed.isEmpty ? CGRect(origin: .zero, size: size) : placed
        return Rectangle()
            .fill(Color.clear)
            .contentShape(Rectangle())
            .frame(width: max(frame.width, Metrics.hitTarget), height: max(frame.height, Metrics.hitTarget))
            .gesture(
                DragGesture(minimumDistance: 3)
                    .onChanged { value in
                        let from = begin("drag")
                        if overlays.maskDragTarget == .mask {
                            let startCenter = geometry.placement.framePoint(forPlace: from.center)
                            let moved = CGPoint(
                                x: startCenter.x * size.width + value.translation.width, y: startCenter.y * size.height + value.translation.height
                            )
                            let point = geometry.placement.placePoint(forFrame: OverlayPoint(x: moved.x / size.width, y: moved.y / size.height))
                            overlays.updateMaskPlacement { $0.center = point }
                        } else {
                            let delta = CGSize(
                                width: value.translation.width - lastTranslation.width, height: value.translation.height - lastTranslation.height
                            )
                            lastTranslation = value.translation
                            let scale = max(0.001, geometry.scale)
                            overlays.panMaskedPicture(by: CGSize(width: delta.width / scale, height: delta.height / scale), placeSize: geometry.rect.size)
                        }
                    }
                    .onEnded { _ in end("drag") }
            )
            .simultaneousGesture(
                MagnifyGesture()
                    .onChanged { value in
                        let from = begin("pinch")
                        if overlays.maskDragTarget == .mask {
                            let factor = Double(value.magnification)
                            overlays.updateMaskPlacement { placement in
                                if media.mask?.shape == .band {
                                    placement.height = from.height * factor
                                } else if media.mask?.shape != .line {
                                    placement.width = from.width * factor
                                    placement.height = from.height * factor
                                }
                            }
                        } else {
                            overlays.zoomMaskedPicture(by: Double(value.magnification / lastMagnification))
                            lastMagnification = value.magnification
                        }
                    }
                    .onEnded { _ in end("pinch") }
            )
            .simultaneousGesture(
                RotateGesture()
                    .onChanged { value in
                        guard overlays.maskDragTarget == .mask else { return }
                        let from = begin("rotate")
                        overlays.updateMaskPlacement { $0.rotation = from.rotation + value.rotation.degrees }
                    }
                    .onEnded { _ in end("rotate") }
            )
            .position(x: frame.midX, y: frame.midY)
            .accessibilityElement()
            .accessibilityLabel(Text("Mask"))
            .accessibilityHint(Text("Drag to move it, pinch to resize it, or use the actions"))
            .accessibilityActions {
                Button("Move up") { overlays.nudgeMask(x: 0, y: -OverlaysViewModel.maskStep) }
                Button("Move down") { overlays.nudgeMask(x: 0, y: OverlaysViewModel.maskStep) }
                Button("Move left") { overlays.nudgeMask(x: -OverlaysViewModel.maskStep, y: 0) }
                Button("Move right") { overlays.nudgeMask(x: OverlaysViewModel.maskStep, y: 0) }
                Button("Bigger") { overlays.scaleMask(by: 1.1) }
                Button("Smaller") { overlays.scaleMask(by: 1 / 1.1) }
            }
            .accessibilityIdentifier("edit.mask.area")
    }

    // MARK: - Gesture state

    /// The mask as a finger took it: the gesture is one undo step.
    private func begin(_ gesture: String) -> MaskPlacement {
        gestures.insert(gesture)
        if let start { return start }
        viewModel.player.pause()
        viewModel.beginChange()
        let now = viewModel.selectedMedia.flatMap { overlays.maskPlacementAtPlayhead(of: $0) } ?? MaskPlacement()
        start = now
        lastTranslation = .zero
        lastMagnification = 1
        return now
    }

    /// A gesture let go; the last one to end closes the undo step.
    private func end(_ gesture: String) {
        gestures.remove(gesture)
        guard start != nil, gestures.isEmpty else { return }
        start = nil
        lastTranslation = .zero
        lastMagnification = 1
        viewModel.endChange()
    }

    private func loadGhost(_ media: MediaOverlay) async {
        let time = media.fileTime(at: viewModel.player.currentTime, in: viewModel.edit.timeline) ?? media.startInFile
        let image = await thumbnails.picture(
            of: EditMediaFiles.url(for: media.fileName), isVideo: media.kind == .video, at: time, maxPixelSize: 720
        )
        if let image { ghost = (media.id, image) }
    }
}
