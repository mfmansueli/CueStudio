//
//  MediaToolView.swift
//  Cue Studio
//

import PhotosUI
import SwiftUI

/// Media (B-roll): play, time, undo and redo; the media track; then "Add photo or video" (the
/// library picker; the file is copied into the app). Several can show at once (up to three), in a
/// stacking order the picked one can move up or down. With one picked: Full screen or Window, the
/// window's shape (a crop) and size, and Remove. On the preview, drag the window to move it and
/// pinch to resize it.
struct MediaToolView: View {
    let viewModel: QuickEditViewModel

    @State private var pickedItem: PhotosPickerItem?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            QuickEditTransportBar(viewModel: viewModel)
            LayerTrackView(viewModel: viewModel, bars: viewModel.mediaBars, tint: Palette.info, identifier: "edit.mediaTrack")
            if let media = viewModel.selectedMedia {
                selectedActions(media)
            } else {
                addButton
                Text(viewModel.edit.media.isEmpty
                    ? String(localized: "Shows over your take at the playhead · up to three at once")
                    : String(localized: "Tap a bar to change it · drag to move"))
                    .font(.caption)
                    .foregroundStyle(Palette.ink.opacity(0.45))
                    .lineLimit(1)
            }
        }
        .onChange(of: pickedItem) { _, item in
            guard let item else { return }
            pickedItem = nil
            Task { await viewModel.importMedia(item) }
        }
    }

    private var addButton: some View {
        PhotosPicker(selection: $pickedItem, matching: .any(of: [.images, .videos]), photoLibrary: .shared()) {
            HStack(spacing: 8) {
                if viewModel.isImportingMedia {
                    ProgressView().tint(Palette.bg)
                } else {
                    Image(systemName: "photo.badge.plus")
                }
                viewModel.isImportingMedia ? Text("Adding…") : Text("Add photo or video")
            }
        }
        .buttonStyle(.cueLight(.medium))
        .disabled(viewModel.isImportingMedia)
        .accessibilityIdentifier("edit.addMediaButton")
    }

    private func selectedActions(_ media: MediaOverlay) -> some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                Picker("Layout", selection: Binding(
                    get: { media.layout },
                    set: { layout in viewModel.updateMedia(media.id) { $0.layout = layout } }
                )) {
                    ForEach(MediaLayout.allCases) { Text($0.label).tag($0) }
                }
                .pickerStyle(.segmented)
                .accessibilityIdentifier("edit.mediaLayout")
                if viewModel.edit.media.count > 1 {
                    Button { viewModel.restack(media.id, up: true) } label: {
                        Image(systemName: "square.2.layers.3d.top.filled")
                    }
                    .buttonStyle(.cueIcon(.surface, diameter: 36))
                    .disabled(!viewModel.canRestack(media.id, up: true))
                    .accessibilityLabel(Text("Bring forward"))
                    .accessibilityIdentifier("edit.mediaForwardButton")
                    Button { viewModel.restack(media.id, up: false) } label: {
                        Image(systemName: "square.2.layers.3d.bottom.filled")
                    }
                    .buttonStyle(.cueIcon(.surface, diameter: 36))
                    .disabled(!viewModel.canRestack(media.id, up: false))
                    .accessibilityLabel(Text("Send backward"))
                    .accessibilityIdentifier("edit.mediaBackwardButton")
                }
                Button { viewModel.deleteMedia(media.id) } label: {
                    Image(systemName: "trash")
                }
                .buttonStyle(.cueIcon(.danger, diameter: 36))
                .accessibilityLabel(Text("Remove media"))
                .accessibilityIdentifier("edit.deleteMediaButton")
                Button { viewModel.selectMedia(nil) } label: {
                    Image(systemName: "checkmark")
                }
                .buttonStyle(.cueIcon(.surface, diameter: 36))
                .accessibilityLabel(Text("Done with this media"))
            }
            if media.layout == .window {
                HStack(spacing: 6) {
                    ForEach(MediaShape.allCases) { shape in
                        Button { viewModel.updateMedia(media.id) { $0.shape = shape } } label: {
                            FilterChip(label: shape.label, isSelected: media.shape == shape, height: 30)
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("edit.mediaShape.\(shape.rawValue)")
                    }
                    Spacer(minLength: 0)
                }
                Slider(
                    value: Binding(
                        get: { media.width },
                        set: { width in viewModel.updateMedia(media.id) { $0.width = width } }
                    ),
                    in: MediaOverlay.widthRange,
                    onEditingChanged: { editing in editing ? viewModel.beginChange() : viewModel.endChange() }
                )
                .tint(Palette.acc)
                .accessibilityLabel(Text("Size"))
                .accessibilityIdentifier("edit.mediaSize")
            } else {
                Text("Fills the frame · switch to Window to place and size it")
                    .font(.caption)
                    .foregroundStyle(Palette.ink.opacity(0.45))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}
