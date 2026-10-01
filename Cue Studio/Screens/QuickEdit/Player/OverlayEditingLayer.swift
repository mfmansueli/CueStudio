//
//  OverlayEditingLayer.swift
//  Cue Studio
//

import SwiftUI

/// Handles over the preview for what is laid on the video. Text: an outline around each text on
/// screen (dashed; yellow when picked); tap picks it, tap again writes it, drag moves it. Media:
/// the window's outline; drag moves it, pinch resizes it. The texts and media themselves are drawn
/// into the video, exactly as they export; while a finger moves one, a copy follows it and the
/// change lands when it lifts.
struct OverlayEditingLayer: View {
    let viewModel: QuickEditViewModel
    let size: CGSize

    @State private var draggedTextID: UUID?
    @State private var dragOffset: CGSize = .zero
    @State private var mediaScale: CGFloat = 1

    var body: some View {
        ZStack(alignment: .topLeading) {
            Color.clear.allowsHitTesting(false)
            ForEach(viewModel.visibleTexts) { text in
                textHandle(text)
            }
            if let media = viewModel.visibleMedia, media.layout == .window {
                mediaHandle(media)
            }
        }
        .frame(width: size.width, height: size.height)
    }

    // MARK: - Text

    private func textHandle(_ text: TextOverlay) -> some View {
        let rect = viewModel.frame(ofText: text, in: size)
        let isSelected = text.id == viewModel.selectedTextID
        let isDragged = text.id == draggedTextID
        let offset = isDragged ? dragOffset : .zero
        return ZStack {
            if isDragged, let image = viewModel.image(ofText: text, width: size.width) {
                Image(uiImage: image)
                    .resizable()
                    .frame(width: rect.width, height: rect.height)
                    .opacity(0.9)
            }
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .strokeBorder(
                    isSelected ? Palette.acc : Palette.ink.opacity(0.6),
                    style: StrokeStyle(lineWidth: isSelected ? 2 : 1, dash: isSelected ? [] : [4, 3])
                )
                .frame(width: rect.width + 8, height: rect.height + 8)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            if isSelected {
                viewModel.editingTextID = text.id
            } else {
                viewModel.selectText(text.id)
            }
        }
        .gesture(
            DragGesture(minimumDistance: 3)
                .onChanged { value in
                    if draggedTextID != text.id {
                        draggedTextID = text.id
                        viewModel.selectedTextID = text.id
                        viewModel.player.pause()
                    }
                    dragOffset = value.translation
                }
                .onEnded { value in
                    // From where it shows now (its keyframes may have moved it).
                    let shown = viewModel.motionState(of: .text(text.id)).center
                    let moved = OverlayPoint(
                        x: shown.x + Double(value.translation.width / max(1, size.width)),
                        y: shown.y + Double(value.translation.height / max(1, size.height))
                    ).clamped
                    viewModel.moveText(text.id, to: moved)
                    draggedTextID = nil
                    dragOffset = .zero
                }
        )
        .position(x: rect.midX + offset.width, y: rect.midY + offset.height)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(text.isEmpty ? text.role.label : text.displayText))
        .accessibilityHint(isSelected ? Text("Tap to write") : Text("Tap to select"))
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
        .accessibilityIdentifier("edit.textHandle")
    }

    // MARK: - Media

    private func mediaHandle(_ media: MediaOverlay) -> some View {
        let rect = viewModel.frame(ofMedia: media, in: size)
        let isSelected = media.id == viewModel.selectedMediaID
        let isDragged = draggedTextID == media.id
        let offset = isDragged ? dragOffset : .zero
        return RoundedRectangle(cornerRadius: 4, style: .continuous)
            .strokeBorder(isSelected ? Palette.acc : Palette.ink.opacity(0.6), style: StrokeStyle(lineWidth: 2, dash: isSelected ? [] : [5, 4]))
            .frame(width: rect.width * mediaScale, height: rect.height * mediaScale)
            .contentShape(Rectangle())
            .onTapGesture { viewModel.selectMedia(media.id) }
            .gesture(
                DragGesture(minimumDistance: 3)
                    .onChanged { value in
                        if draggedTextID != media.id {
                            draggedTextID = media.id
                            viewModel.selectedMediaID = media.id
                            viewModel.player.pause()
                        }
                        dragOffset = value.translation
                    }
                    .onEnded { value in
                        let moved = OverlayPoint(
                            x: Double(rect.midX + value.translation.width) / Double(max(1, size.width)),
                            y: Double(rect.midY + value.translation.height) / Double(max(1, size.height))
                        ).clamped
                        viewModel.moveMedia(media.id, to: moved)
                        draggedTextID = nil
                        dragOffset = .zero
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
