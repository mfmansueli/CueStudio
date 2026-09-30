//
//  ClipsSheet.swift
//  Cue Studio
//

import PhotosUI
import SwiftUI

/// The montage: every section in play order, to put in another order (drag the handles), copy or
/// take out (swipe), and other takes or videos to add after the picked section (or at the end).
/// Reordering is a mode of its own, apart from picking, trimming and scrubbing on the timeline.
/// Taking a section out never deletes the take or the video it came from.
struct ClipsSheet: View {
    let viewModel: QuickEditViewModel

    @Environment(\.dismiss) private var dismiss
    @Environment(VideoThumbnailService.self) private var thumbnails
    @State private var picksTake = false
    @State private var pickedVideo: PhotosPickerItem?
    @State private var images: [UUID: UIImage] = [:]

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(viewModel.clips) { clip in
                        row(clip)
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) { viewModel.removeSection(clip.id) } label: {
                                    Label("Remove", systemImage: "trash")
                                }
                                Button { viewModel.duplicateSection(clip.id) } label: {
                                    Label("Copy", systemImage: "plus.square.on.square")
                                }
                                .tint(Palette.neutralAction)
                            }
                    }
                    .onMove { from, to in
                        guard let source = from.first else { return }
                        // `onMove` counts the destination before the removal.
                        viewModel.moveSection(from: source, to: to > source ? to - 1 : to)
                    }
                } footer: {
                    Text("Drag to reorder · swipe to copy or remove. Removing a section never deletes the take or video it came from.")
                }
                Section {
                    Button {
                        picksTake = true
                    } label: {
                        Label("Add a take", systemImage: "film.stack")
                    }
                    .accessibilityIdentifier("clips.addTakeButton")
                    // The picker builds its label off the main actor.
                    let isImporting = viewModel.isImportingMedia
                    PhotosPicker(selection: $pickedVideo, matching: .videos) {
                        Label(isImporting ? String(localized: "Adding…") : String(localized: "Add a video"), systemImage: "video.badge.plus")
                    }
                    .disabled(viewModel.isImportingMedia)
                    .accessibilityIdentifier("clips.addVideoButton")
                }
            }
            .environment(\.editMode, .constant(.active))
            .scrollContentBackground(.hidden)
            .background(Palette.surface)
            .navigationTitle("Clips")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .accessibilityIdentifier("clips.doneButton")
                }
            }
            .sheet(isPresented: $picksTake) { takes }
            .onChange(of: pickedVideo) { _, item in
                guard let item else { return }
                pickedVideo = nil
                Task { await viewModel.addClip(importing: item) }
            }
            .task(id: viewModel.clips.map(\.id)) { await loadThumbnails() }
        }
        .presentationDetents([.medium, .large])
    }

    // MARK: - Sections

    private func row(_ clip: QuickEditViewModel.Clip) -> some View {
        HStack(spacing: 12) {
            Group {
                if let image = images[clip.id] {
                    Image(uiImage: image).resizable().scaledToFill()
                } else {
                    LinearGradient(colors: [Palette.thumbnailTop, Palette.thumbnailBottom], startPoint: .top, endPoint: .bottom)
                }
            }
            .frame(width: 36, height: 56)
            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(clip.title).font(.subheadline.weight(.semibold)).lineLimit(1)
                Text(DurationText.clock(clip.duration))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(Palette.ink2)
            }
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text("Section \(clip.index + 1), \(clip.title), \(DurationText.clock(clip.duration))"))
        .accessibilityIdentifier("clips.row")
    }

    /// The library's takes to add, newest first.
    private var takes: some View {
        NavigationStack {
            List(viewModel.takesForMontage) { take in
                Button {
                    picksTake = false
                    Task { await viewModel.addClip(from: take) }
                } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(take.scriptTitle).foregroundStyle(Palette.ink)
                        Text("Take \(take.number) · \(DurationText.clock(take.duration))")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(Palette.ink2)
                    }
                }
                .accessibilityIdentifier("clips.take")
            }
            .navigationTitle("Add a take")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { picksTake = false }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func loadThumbnails() async {
        var loaded: [UUID: UIImage] = [:]
        for clip in viewModel.clips {
            let url = viewModel.videoURL(ofSource: clip.sourceID)
            if let image = await thumbnails.frames(for: url, at: [clip.thumbnailTime], tolerance: 0.5).first ?? nil {
                loaded[clip.id] = image
            }
        }
        images = loaded
    }
}
