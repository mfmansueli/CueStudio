//
//  AddMediaSheet.swift
//  Cue Studio
//

import PhotosUI
import SwiftUI

/// "Add photo or video": the photo library right in the sheet, and where the pick goes: on top of
/// the video (on the text track, for 3 s; a video for its length) or as a clip after the one at
/// the playhead (videos only: the video track plays recordings).
struct AddMediaSheet: View {
    @Bindable var viewModel: QuickEditViewModel

    @Environment(\.dismiss) private var dismiss
    @State private var picked: PhotosPickerItem?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            SheetHeader(title: String(localized: "Add photo or video"))
            Picker("Where it goes", selection: $viewModel.mediaInsertMode) {
                ForEach(MediaInsertMode.allCases) { mode in
                    Text(mode.label).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .accessibilityIdentifier("edit.mediaMode")
            ZStack {
                PhotosPicker(
                    selection: $picked,
                    matching: viewModel.mediaInsertMode == .clip ? .videos : .any(of: [.images, .videos]),
                    photoLibrary: .shared()
                ) {
                    EmptyView()
                }
                .photosPickerStyle(.inline)
                .photosPickerDisabledCapabilities([.selectionActions, .stagingArea])
                .photosPickerAccessoryVisibility(.hidden, edges: .all)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                if viewModel.isImportingMedia {
                    ProgressView().tint(Palette.ink)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Palette.durationBadge)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .onChange(of: picked) { _, item in
            guard let item else { return }
            Task {
                switch viewModel.mediaInsertMode {
                case .overlay: await viewModel.importMedia(item)
                case .clip: await viewModel.addClip(importing: item)
                }
                picked = nil
                dismiss()
            }
        }
        .cueSheetChrome()
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}
