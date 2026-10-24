//
//  SplitAreaLayer.swift
//  Cue Studio
//

import SwiftUI

/// The split screen on the preview, while a support shows at the playhead and the video is paused. A tap on an area picks its
/// support with that area; the picked area has the yellow outline and its name, the other a dashed one. A drag in the picked
/// area moves what it shows and a pinch zooms it, the picture following the finger one to one (a copy drawn here, the video
/// leaving nothing behind it), resisting past its edge, with a tick when it's centered; the change lands when the finger
/// lifts. The seam's grip drags between 40, 50 and 60%.
struct SplitAreaLayer: View {
    let viewModel: QuickEditViewModel
    let size: CGSize

    @Environment(VideoThumbnailService.self) private var thumbnails
    /// The area under a finger, how far it moved and how much it was pinched.
    @State private var moving: (area: SplitArea, translation: CGSize, scale: CGFloat)?
    /// What the area under the finger shows, upright, for the copy that follows it.
    @State private var proxy: (area: SplitArea, image: UIImage)?
    @State private var wasCentered = false
    @State private var seamStart: Double?

    private var overlays: OverlaysViewModel { viewModel.overlays }

    var body: some View {
        if !viewModel.player.isPlaying, let support = overlays.supportAtPlayhead {
            let isPicked = viewModel.selection == .media(support.id)
            let areas = SplitPlacement.areas(viewModel.edit.splitScreen.layout(id: support.splitLayoutID), in: size)
            ZStack(alignment: .topLeading) {
                ForEach(SplitArea.allCases) { area in
                    areaView(area, rect: areas.rect(of: area), support: support, isPicked: isPicked)
                }
                if isPicked { seamGrip(areas: areas) }
            }
            .frame(width: size.width, height: size.height, alignment: .topLeading)
        }
    }

    // MARK: - An area

    private func areaView(_ area: SplitArea, rect: CGRect, support: MediaOverlay, isPicked: Bool) -> some View {
        let isOn = isPicked && overlays.selectedArea == area
        return ZStack(alignment: .topLeading) {
            if let moving, moving.area == area, let proxy, proxy.area == area {
                copy(proxy.image, in: rect.size, framing: proposedFraming(area, of: support.id, in: rect.size, moving: moving, content: proxy.image.size))
            }
            if isPicked {
                Rectangle()
                    .strokeBorder(
                        isOn ? Palette.acc : Palette.Editor.overlayOutline,
                        style: StrokeStyle(lineWidth: 2, dash: isOn ? [] : [5, 4])
                    )
                    .shadow(color: Palette.Editor.overlayOutlineHalo, radius: 1.5)
                    .allowsHitTesting(false)
                if isOn {
                    Text(area.label)
                        .font(.system(.caption, weight: .semibold))
                        .foregroundStyle(Palette.ink)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Palette.Takes.durationBadge, in: Capsule())
                        .padding(8)
                        .allowsHitTesting(false)
                }
            }
        }
        .frame(width: rect.width, height: rect.height)
        .clipped()
        .contentShape(Rectangle())
        .onTapGesture { overlays.pickArea(area, of: support.id) }
        .gesture(dragGesture(area, support: support, area: rect.size))
        .simultaneousGesture(pinchGesture(area, support: support, area: rect.size))
        .offset(x: rect.minX, y: rect.minY)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(area == .main ? Text("Main video area") : Text("Support area"))
        .accessibilityHint(isOn ? Text("Drag to move what it shows, pinch to zoom, or use the actions") : Text("Tap to pick this area"))
        .accessibilityAddTraits(isOn ? [.isButton, .isSelected] : .isButton)
        .accessibilityAction { overlays.pickArea(area, of: support.id) }
        .accessibilityActions { framingActions(area, of: support.id, content: overlays.contentSize(area, of: support.id), area: rect.size) }
        .accessibilityIdentifier("edit.splitArea.\(area.rawValue)")
    }

    /// The copy that follows the finger, placed as the export will place it.
    private func copy(_ image: UIImage, in area: CGSize, framing: (framing: AreaFraming, rubber: CGSize)) -> some View {
        let placed = SplitPlacement.place(image.size, in: area, framing: framing.framing)
        return ZStack(alignment: .topLeading) {
            Color.black
            Image(uiImage: image)
                .resizable()
                .frame(width: placed.size.width, height: placed.size.height)
                .offset(x: placed.origin.x + framing.rubber.width, y: placed.origin.y + framing.rubber.height)
        }
        .frame(width: area.width, height: area.height, alignment: .topLeading)
        .clipped()
        .allowsHitTesting(false)
    }

    /// Where the finger has the area's picture now: the framing it lands on, and how far past an edge it's pulled (a third
    /// of the way, so it resists).
    private func proposedFraming(
        _ area: SplitArea, of id: UUID, in size: CGSize, moving: (area: SplitArea, translation: CGSize, scale: CGFloat), content: CGSize
    ) -> (framing: AreaFraming, rubber: CGSize) {
        var base = overlays.areaFraming(area, of: id)
        base.zoom = min(max(base.clampedZoom * Double(moving.scale), AreaFraming.zoomRange.lowerBound), AreaFraming.zoomRange.upperBound)
        let framing = SplitPlacement.dragged(base, content: content, area: size, by: moving.translation)
        let past = SplitPlacement.overshoot(base, content: content, area: size, by: moving.translation)
        return (framing, CGSize(width: past.width / 3, height: past.height / 3))
    }

    private func dragGesture(_ area: SplitArea, support: MediaOverlay, area size: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 3)
            .onChanged { value in
                if moving?.area != area { begin(area, support: support) }
                moving = (area, value.translation, moving?.scale ?? 1)
                tickWhenCentered(area, support: support, size: size)
            }
            .onEnded { _ in land(area, support: support, size: size) }
    }

    private func pinchGesture(_ area: SplitArea, support: MediaOverlay, area size: CGSize) -> some Gesture {
        MagnifyGesture()
            .onChanged { value in
                if moving?.area != area { begin(area, support: support) }
                moving = (area, moving?.translation ?? .zero, value.magnification)
            }
            .onEnded { _ in land(area, support: support, size: size) }
    }

    /// A finger took the area: it's picked, and its picture is read for the copy.
    private func begin(_ area: SplitArea, support: MediaOverlay) {
        viewModel.player.pause()
        overlays.pickArea(area, of: support.id)
        moving = (area, .zero, 1)
        wasCentered = false
        guard let source = overlays.areaPictureSource(area, of: support) else { return }
        Task {
            let image = await thumbnails.picture(of: source.url, isVideo: source.isVideo, at: source.time, maxPixelSize: 900)
            if let image, moving?.area == area { proxy = (area, image) }
        }
    }

    /// The finger lifted: the framing lands (one undo step), and the copy goes once the video draws it.
    private func land(_ area: SplitArea, support: MediaOverlay, size: CGSize) {
        guard let moving else { return }
        let content = proxy?.image.size ?? overlays.contentSize(area, of: support.id)
        let landed = proposedFraming(area, of: support.id, in: size, moving: moving, content: content).framing
        overlays.setAreaFraming(landed, for: area, of: support.id)
        self.moving = nil
        Task {
            try? await Task.sleep(for: .milliseconds(250))
            if self.moving == nil { proxy = nil }
        }
    }

    /// One tick when the picture comes to the middle across.
    private func tickWhenCentered(_ area: SplitArea, support: MediaOverlay, size: CGSize) {
        guard let moving, let proxy else { return }
        let framing = proposedFraming(area, of: support.id, in: size, moving: moving, content: proxy.image.size).framing
        let centered = abs(framing.center.x - 0.5) < 0.004
        if centered, !wasCentered { Haptics.snap() }
        wasCentered = centered
    }

    // MARK: - The seam

    private func seamGrip(areas: SplitPlacement.Areas) -> some View {
        let layout = overlays.splitLayout
        let stacked = layout.arrangement == .stacked
        let share = layout.firstShare
        let position = stacked ? size.height * CGFloat(share) : size.width * CGFloat(share)
        return Capsule()
            .fill(Palette.acc)
            .frame(width: stacked ? 36 : 6, height: stacked ? 6 : 36)
            .frame(width: Metrics.hitTarget, height: Metrics.hitTarget)
            .contentShape(Rectangle())
            .position(x: stacked ? size.width / 2 : position, y: stacked ? position : size.height / 2)
            .gesture(
                DragGesture(minimumDistance: 2)
                    .onChanged { value in
                        if seamStart == nil {
                            seamStart = share
                            viewModel.beginChange()
                        }
                        let moved = stacked ? value.translation.height / max(1, size.height) : value.translation.width / max(1, size.width)
                        overlays.dragSeam(toShare: (seamStart ?? share) + Double(moved))
                    }
                    .onEnded { _ in
                        seamStart = nil
                        viewModel.endChange()
                    }
            )
            .accessibilityElement()
            .accessibilityLabel(Text("Seam"))
            .accessibilityValue(Text(layout.ratio.label))
            .accessibilityAdjustableAction { direction in
                overlays.dragSeam(toShare: share + (direction == .increment ? 0.1 : -0.1))
            }
            .accessibilityIdentifier("edit.splitSeam")
    }

    // MARK: - VoiceOver

    @ViewBuilder
    private func framingActions(_ area: SplitArea, of id: UUID, content: CGSize, area size: CGSize) -> some View {
        let step = min(size.width, size.height) * 0.1
        Button("Zoom in") { zoom(area, of: id, by: 1.25) }
        Button("Zoom out") { zoom(area, of: id, by: 0.8) }
        Button("Move up") { move(area, of: id, content: content, area: size, by: CGSize(width: 0, height: -step)) }
        Button("Move down") { move(area, of: id, content: content, area: size, by: CGSize(width: 0, height: step)) }
        Button("Move left") { move(area, of: id, content: content, area: size, by: CGSize(width: -step, height: 0)) }
        Button("Move right") { move(area, of: id, content: content, area: size, by: CGSize(width: step, height: 0)) }
    }

    private func zoom(_ area: SplitArea, of id: UUID, by factor: Double) {
        var framing = overlays.areaFraming(area, of: id)
        framing.zoom = min(max(framing.clampedZoom * factor, AreaFraming.zoomRange.lowerBound), AreaFraming.zoomRange.upperBound)
        overlays.setAreaFraming(framing, for: area, of: id)
    }

    private func move(_ area: SplitArea, of id: UUID, content: CGSize, area size: CGSize, by translation: CGSize) {
        let framing = SplitPlacement.dragged(overlays.areaFraming(area, of: id), content: content, area: size, by: translation)
        overlays.setAreaFraming(framing, for: area, of: id)
    }
}
