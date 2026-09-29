//
//  CoverToolView.swift
//  Cue Studio
//

import PhotosUI
import SwiftUI

/// Cover: the frame under the playhead or a photo from the library, and a title set in the
/// project's style (drag it on the cover to move it). Saved to Photos with every export, ready to
/// pick as the post's cover.
struct CoverToolView: View {
    let viewModel: QuickEditViewModel

    @State private var pickedItem: PhotosPickerItem?
    @State private var title = ""
    @FocusState private var isWritingTitle: Bool

    var body: some View {
        let picking = viewModel.edit.cover == nil || viewModel.isPickingCoverFrame
        VStack(alignment: .leading, spacing: 10) {
            if picking {
                QuickEditTransportBar(viewModel: viewModel)
                LayerTrackView(viewModel: viewModel, bars: [], tint: Palette.acc, identifier: "edit.coverTrack", height: 30)
            }
            HStack(spacing: 8) {
                if picking {
                    Button(action: viewModel.useFrameAsCover) {
                        Label("Use this frame", systemImage: "film")
                    }
                    .buttonStyle(.cueLight(.medium))
                    .accessibilityIdentifier("edit.coverFrameButton")
                    if viewModel.edit.cover != nil {
                        Button("Cancel") { viewModel.isPickingCoverFrame = false }
                            .buttonStyle(.cueSecondary(.medium, expands: false))
                    }
                } else {
                    Button {
                        viewModel.isPickingCoverFrame = true
                    } label: {
                        Label("Change frame", systemImage: "film")
                    }
                    .buttonStyle(.cueSecondary(.medium))
                    .accessibilityIdentifier("edit.coverChangeFrameButton")
                }
                PhotosPicker(selection: $pickedItem, matching: .images, photoLibrary: .shared()) {
                    Label("Photo", systemImage: "photo")
                }
                .buttonStyle(.cueSecondary(.medium, expands: false))
                .disabled(viewModel.isImportingMedia)
                .accessibilityIdentifier("edit.coverPhotoButton")
            }
            if viewModel.edit.cover != nil, !picking {
                HStack(spacing: 8) {
                    TextField("Title on the cover", text: $title)
                        .focused($isWritingTitle)
                        .submitLabel(.done)
                        .onSubmit { viewModel.setCoverTitle(title) }
                        .padding(.horizontal, 14)
                        .frame(height: Metrics.mediumButtonHeight)
                        .background(Palette.surface2, in: Capsule())
                        .accessibilityIdentifier("edit.coverTitleField")
                    Button { viewModel.removeCover() } label: {
                        Image(systemName: "trash")
                    }
                    .buttonStyle(.cueIcon(.danger, diameter: Metrics.mediumButtonHeight))
                    .accessibilityLabel(Text("Remove cover"))
                    .accessibilityIdentifier("edit.removeCoverButton")
                }
            }
            Text(hint)
                .font(.caption)
                .foregroundStyle(Palette.ink.opacity(0.45))
                .lineLimit(2)
        }
        .onAppear {
            title = viewModel.edit.cover?.title ?? ""
            viewModel.drawCover()
        }
        .onChange(of: viewModel.edit.cover) { _, cover in
            if !isWritingTitle { title = cover?.title ?? "" }
            viewModel.drawCover()
        }
        .onChange(of: isWritingTitle) { _, writing in
            if !writing { viewModel.setCoverTitle(title) }
        }
        .onChange(of: pickedItem) { _, item in
            guard let item else { return }
            pickedItem = nil
            Task { await viewModel.useCoverPhoto(item) }
        }
    }

    private var hint: String {
        viewModel.edit.cover == nil || viewModel.isPickingCoverFrame
            ? String(localized: "Move the playhead to the frame you want, or pick a photo")
            : String(localized: "Drag on the cover to move the title · saved to Photos when you export")
    }
}
