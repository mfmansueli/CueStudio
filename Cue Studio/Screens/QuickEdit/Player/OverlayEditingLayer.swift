//
//  OverlayEditingLayer.swift
//  Cue Studio
//

import SwiftUI

/// Editing right on the preview. Every text on screen can be tapped: the picked one gets a yellow
/// outline 5 pt around it, a ✕ to delete it and a corner handle to scale it; tapped again, Text
/// style opens. Dragging a text moves it, with yellow guides through the middle (it sticks there,
/// with a tick) and the platform's safe area dashed; with keyframes, the drag sets the one at the
/// playhead. Dragging the caption moves every caption up or down (sticking to top, middle and
/// bottom). A photo or video in a window moves and pinches.
///
/// Texts and captions are drawn into the video exactly as they export; while a finger moves one, a
/// copy follows it and the change lands when it lifts.
struct OverlayEditingLayer: View {
    let viewModel: QuickEditViewModel
    let size: CGSize

    private enum Drag: Equatable {
        case text(UUID, offset: CGSize)
        case scale(UUID, translation: CGSize)
        case caption(UUID, y: Double)
        case media(UUID, offset: CGSize)
    }

    @State private var drag: Drag?
    @State private var guides: (vertical: Bool, horizontal: Bool) = (false, false)
    @State private var mediaScale: CGFloat = 1

    var body: some View {
        ZStack(alignment: .topLeading) {
            Color.clear.allowsHitTesting(false)
            if drag != nil { dragGuides }
            if !viewModel.player.isPlaying, let caption = viewModel.previewCaption(in: size) {
                captionHandle(caption.id, frame: caption.frame)
            }
            if let media = viewModel.visibleMedia, media.layout == .window {
                mediaHandle(media)
            }
            ForEach(viewModel.visibleTexts) { text in
                textHandle(text)
            }
        }
        .frame(width: size.width, height: size.height)
        .coordinateSpace(name: Self.space)
    }

    private static let space = "edit.preview.space"

    // MARK: - Guides

    @ViewBuilder
    private var dragGuides: some View {
        let safe = viewModel.safeArea(in: size)
        RoundedRectangle(cornerRadius: 6, style: .continuous)
            .strokeBorder(Palette.Camera.safeZoneLine, style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
            .frame(width: safe.width, height: safe.height)
            .offset(x: safe.minX, y: safe.minY)
            .allowsHitTesting(false)
        if guides.vertical {
            Rectangle().fill(Palette.acc).frame(width: 1, height: size.height)
                .offset(x: size.width / 2 - 0.5)
                .allowsHitTesting(false)
        }
        if guides.horizontal {
            Rectangle().fill(Palette.acc).frame(width: size.width, height: 1)
                .offset(y: size.height / 2 - 0.5)
                .allowsHitTesting(false)
        }
    }

    // MARK: - Text

    private func textHandle(_ text: TextOverlay) -> some View {
        let rect = viewModel.frame(ofText: text, in: size)
        let isSelected = viewModel.selection == .text(text.id)
        let offset: CGSize = if case .text(text.id, let moved) = drag { moved } else { .zero }
        let scale: CGFloat = if case .scale(text.id, let translation) = drag {
            CGFloat(QuickEditViewModel.scaleFactor(for: translation))
        } else {
            1
        }
        let isDragged = offset != .zero || scale != 1
        return ZStack {
            if isDragged, let image = viewModel.image(ofText: text, width: size.width) {
                Image(uiImage: image)
                    .resizable()
                    .frame(width: rect.width * scale, height: rect.height * scale)
                    .opacity(0.92)
            }
            Rectangle()
                .fill(Color.clear)
                .contentShape(Rectangle())
                .frame(width: max(rect.width, Metrics.hitTarget), height: max(rect.height, Metrics.hitTarget))
                .onTapGesture { viewModel.tapText(text.id) }
                .gesture(moveGesture(text, rect: rect))
            if isSelected {
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .strokeBorder(Palette.acc, lineWidth: 2)
                    .frame(width: rect.width * scale + 10, height: rect.height * scale + 10)
                    .allowsHitTesting(false)
                cornerButton("xmark", label: Text("Delete text"), id: "edit.textDelete") {
                    viewModel.deleteText(text.id)
                }
                .offset(x: -(rect.width * scale / 2 + 5), y: -(rect.height * scale / 2 + 5))
                cornerButton("arrow.up.left.and.arrow.down.right", label: Text("Scale text"), id: "edit.textScale") {}
                    .gesture(scaleGesture(text))
                    .offset(x: rect.width * scale / 2 + 5, y: rect.height * scale / 2 + 5)
            }
        }
        .position(x: rect.midX + offset.width, y: rect.midY + offset.height)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Text(text.isEmpty ? text.role.label : text.displayText))
        .accessibilityHint(isSelected ? Text("Tap to style") : Text("Tap to select"))
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
        .accessibilityIdentifier("edit.textHandle")
    }

    /// White, 24 pt, held from 44 pt.
    private func cornerButton(_ symbol: String, label: Text, id: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(Color.black)
                .frame(width: 24, height: 24)
                .background(Color.white, in: Circle())
                .shadow(color: Palette.textShadow, radius: 2, y: 1)
                .frame(width: Metrics.hitTarget, height: Metrics.hitTarget)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .accessibilityIdentifier(id)
    }

    private func moveGesture(_ text: TextOverlay, rect: CGRect) -> some Gesture {
        DragGesture(minimumDistance: 3, coordinateSpace: .named(Self.space))
            .onChanged { value in
                if drag == nil {
                    viewModel.player.pause()
                    if viewModel.selection != .text(text.id) { viewModel.selection = .text(text.id) }
                }
                let shown = viewModel.motionState(of: .text(text.id)).center
                let proposed = OverlayPoint(
                    x: shown.x + Double(value.translation.width / max(1, size.width)),
                    y: shown.y + Double(value.translation.height / max(1, size.height))
                )
                let snapped = QuickEditViewModel.snapped(proposed)
                if (snapped.vertical && !guides.vertical) || (snapped.horizontal && !guides.horizontal) { Haptics.snap() }
                guides = (snapped.vertical, snapped.horizontal)
                drag = .text(text.id, offset: CGSize(
                    width: CGFloat(snapped.center.x - shown.x) * size.width,
                    height: CGFloat(snapped.center.y - shown.y) * size.height
                ))
            }
            .onEnded { value in
                let shown = viewModel.motionState(of: .text(text.id)).center
                let proposed = OverlayPoint(
                    x: shown.x + Double(value.translation.width / max(1, size.width)),
                    y: shown.y + Double(value.translation.height / max(1, size.height))
                )
                viewModel.moveText(text.id, to: QuickEditViewModel.snapped(proposed).center)
                endDrag()
            }
    }

    private func scaleGesture(_ text: TextOverlay) -> some Gesture {
        DragGesture(minimumDistance: 1, coordinateSpace: .named(Self.space))
            .onChanged { value in
                if drag == nil { viewModel.player.pause() }
                drag = .scale(text.id, translation: value.translation)
            }
            .onEnded { value in
                viewModel.scaleText(text.id, by: value.translation)
                endDrag()
            }
    }

    private func endDrag() {
        drag = nil
        guides = (false, false)
    }

    // MARK: - Caption

    private func captionHandle(_ id: UUID, frame: CGRect) -> some View {
        let isSelected = viewModel.selection == .caption(id)
        let draggedY: Double? = if case .caption(id, let y) = drag { y } else { nil }
        let offset = draggedY.map { CGFloat($0 - viewModel.captionY) * size.height } ?? 0
        return ZStack {
            Rectangle()
                .fill(Color.clear)
                .contentShape(Rectangle())
                .frame(width: max(frame.width, Metrics.hitTarget), height: max(frame.height, Metrics.hitTarget))
                .onTapGesture { viewModel.tapCaption(id) }
                .gesture(captionGesture(id))
            if isSelected || draggedY != nil {
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .strokeBorder(Palette.acc, lineWidth: 2)
                    .frame(width: frame.width + 8, height: frame.height + 8)
                    .allowsHitTesting(false)
            }
        }
        .position(x: frame.midX, y: frame.midY + offset)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Caption"))
        .accessibilityHint(Text("Drag up or down to move every caption"))
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
        .accessibilityIdentifier("edit.captionHandle")
    }

    private func captionGesture(_ id: UUID) -> some Gesture {
        DragGesture(minimumDistance: 3, coordinateSpace: .named(Self.space))
            .onChanged { value in
                if drag == nil {
                    viewModel.player.pause()
                    if viewModel.selection != .caption(id) { viewModel.selection = .caption(id) }
                }
                let placed = QuickEditViewModel.snappedCaption(viewModel.captionY + Double(value.translation.height / max(1, size.height)))
                if placed.stop != nil, !guides.horizontal { Haptics.snap() }
                guides = (false, placed.stop == 0.5)
                drag = .caption(id, y: placed.y)
            }
            .onEnded { value in
                viewModel.moveCaptions(toY: viewModel.captionY + Double(value.translation.height / max(1, size.height)))
                endDrag()
            }
    }

    // MARK: - Media

    private func mediaHandle(_ media: MediaOverlay) -> some View {
        let rect = viewModel.frame(ofMedia: media, in: size)
        let isSelected = viewModel.selection == .media(media.id)
        let offset: CGSize = if case .media(media.id, let moved) = drag { moved } else { .zero }
        return RoundedRectangle(cornerRadius: 4, style: .continuous)
            .strokeBorder(isSelected ? Palette.acc : Palette.ink.opacity(0.6), style: StrokeStyle(lineWidth: 2, dash: isSelected ? [] : [5, 4]))
            .frame(width: rect.width * mediaScale, height: rect.height * mediaScale)
            .contentShape(Rectangle())
            .onTapGesture { viewModel.selectMedia(media.id) }
            .gesture(
                DragGesture(minimumDistance: 3, coordinateSpace: .named(Self.space))
                    .onChanged { value in
                        if drag == nil {
                            viewModel.player.pause()
                            viewModel.selection = .media(media.id)
                        }
                        drag = .media(media.id, offset: value.translation)
                    }
                    .onEnded { value in
                        let moved = OverlayPoint(
                            x: Double(rect.midX + value.translation.width) / Double(max(1, size.width)),
                            y: Double(rect.midY + value.translation.height) / Double(max(1, size.height))
                        ).clamped
                        viewModel.moveMedia(media.id, to: moved)
                        endDrag()
                    }
            )
            .simultaneousGesture(
                MagnifyGesture()
                    .onChanged { value in mediaScale = value.magnification }
                    .onEnded { value in
                        viewModel.resizeMedia(media.id, by: Double(value.magnification))
                        mediaScale = 1
                    }
            )
            .position(x: rect.midX + offset.width, y: rect.midY + offset.height)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(media.kind == .photo ? Text("Photo") : Text("Video"))
            .accessibilityHint(Text("Drag to move, pinch to resize"))
            .accessibilityIdentifier("edit.mediaHandle")
    }
}
