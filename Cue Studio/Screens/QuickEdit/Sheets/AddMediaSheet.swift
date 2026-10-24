//
//  AddMediaSheet.swift
//  Cue Studio
//

import PhotosUI
import SwiftUI

/// "Add photo or video": the photo library right in the sheet, and where the pick goes, said with the place and length
/// before picking: on top of the video from the playhead (on the text track, for 3 s; a video for its length) or as a clip
/// after the picked one or the one at the playhead (videos only: the video track plays recordings). As a clip, the
/// creator's other takes come first, for a montage of several takes.
struct AddMediaSheet: View {
    @Bindable var viewModel: QuickEditViewModel

    @Environment(\.dismiss) private var dismiss
    @State private var picked: PhotosPickerItem?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            SheetHeader(title: String(localized: "Add photo or video"))
            Picker("Where it goes", selection: Bindable(viewModel.overlays).mediaInsertMode) {
                ForEach(MediaInsertMode.allCases) { mode in
                    Text(mode.label).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .accessibilityIdentifier("edit.mediaMode")
            VStack(alignment: .leading, spacing: 4) {
                Text(viewModel.overlays.mediaInsertMode.explanation)
                    .font(.system(.footnote))
                    .foregroundStyle(Palette.ink2)
                    .accessibilityIdentifier("edit.mediaModeExplanation")
                // Where it lands and for how long, before picking.
                Label(insertionNote, systemImage: "arrow.down.to.line")
                    .font(.system(.footnote, weight: .semibold))
                    .foregroundStyle(Palette.ink)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(Text(insertionNote))
                    .accessibilityIdentifier("edit.mediaInsertionNote")
            }
            .fixedSize(horizontal: false, vertical: true)
            if viewModel.overlays.mediaInsertMode == .clip, !viewModel.clips.addableTakes.isEmpty {
                TakeRow(takes: viewModel.clips.addableTakes) { take in
                    Task {
                        await viewModel.clips.addClip(from: take)
                        dismiss()
                    }
                }
            }
            ZStack {
                PhotosPicker(
                    selection: $picked,
                    matching: viewModel.overlays.mediaInsertMode == .clip ? .videos : .any(of: [.images, .videos]),
                    photoLibrary: .shared()
                ) {
                    EmptyView()
                }
                .photosPickerStyle(.inline)
                .photosPickerDisabledCapabilities([.selectionActions, .stagingArea])
                .photosPickerAccessoryVisibility(.hidden, edges: .all)
                .clipShape(RoundedRectangle(cornerRadius: Metrics.editorCardRadius, style: .continuous))
                if viewModel.isImportingMedia {
                    ProgressView().tint(Palette.ink)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Palette.Takes.durationBadge)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .onChange(of: picked) { _, item in
            guard let item else { return }
            Task {
                switch viewModel.overlays.mediaInsertMode {
                case .overlay: await viewModel.overlays.importMedia(item)
                case .clip: await viewModel.clips.addClip(importing: item)
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

extension AddMediaSheet {
    private var insertionNote: String {
        switch viewModel.overlays.mediaInsertMode {
        case .overlay: viewModel.overlays.insertionNote
        case .clip: viewModel.clips.insertionNote
        }
    }

    /// "Your takes": the other takes in a sideways row, each with its script, number and length; a tap adds it as a clip.
    private struct TakeRow: View {
        let takes: [Take]
        let add: (Take) -> Void

        var body: some View {
            VStack(alignment: .leading, spacing: 8) {
                Text("Your takes")
                    .font(.system(.footnote, weight: .semibold))
                    .foregroundStyle(Palette.ink2)
                ScrollView(.horizontal) {
                    HStack(spacing: 8) {
                        ForEach(takes) { take in
                            Button { add(take) } label: { card(take) }
                                .buttonStyle(.cuePress)
                                .accessibilityElement(children: .ignore)
                                .accessibilityLabel(Text("\(take.scriptTitle) · Take \(take.number)"))
                                .accessibilityValue(Text(DurationText.clock(take.duration)))
                                .accessibilityAddTraits(.isButton)
                                .accessibilityIdentifier("edit.addTake.\(take.id.uuidString)")
                        }
                    }
                }
                .scrollIndicators(.hidden)
            }
        }

        private func card(_ take: Take) -> some View {
            VStack(alignment: .leading, spacing: 2) {
                Text(take.scriptTitle)
                    .font(.system(.subheadline, weight: .semibold))
                    .foregroundStyle(Palette.ink)
                    .lineLimit(1)
                Text(verbatim: "\(String(localized: "Take \(take.number)")) · \(DurationText.clock(take.duration))")
                    .monoFont(.caption)
                    .foregroundStyle(Palette.ink2)
            }
            .frame(width: 150, alignment: .leading)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Palette.fill, in: RoundedRectangle(cornerRadius: Metrics.fieldRadius, style: .continuous))
            .frame(minHeight: Metrics.hitTarget)
        }
    }
}
