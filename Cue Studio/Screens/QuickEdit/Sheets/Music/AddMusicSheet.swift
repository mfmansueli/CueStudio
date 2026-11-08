//
//  AddMusicSheet.swift
//  Cue Studio
//

import SwiftUI
import UniformTypeIdentifiers

/// "Add music or a sound", a tall sheet (choosing in a library: nothing to watch on the video meanwhile) in two parts picked by
/// the system's segmented control, always in sight; the bar's Music and Sound effects each open their own part (owner, canvas 2
/// F13, 07/11/2026). **Music**: the creator's own from Files first, right under the search (copied into the app and laid under
/// the voice), then Cue's library (tracks composed by Cue on recorded instruments, free to use: search, filters, hear, ⓘ for what
/// it covers and its licence, + to add at the playhead), and the note on why songs from Apple Music can't be picked.
/// **Sound effects**: Cue's effects by what they're for. From a music clip's Replace, the music alone.
struct AddMusicSheet: View {
    let viewModel: QuickEditViewModel

    @Environment(\.dismiss) private var dismiss
    @State private var picksFile = false
    @State private var part: Part
    @State private var library: MusicLibraryViewModel
    @FocusState private var isSearching: Bool

    enum Part: Hashable { case music, effects }

    /// `opensOn`: the part the bar's button asked for.
    init(viewModel: QuickEditViewModel, opensOn: Part = .music) {
        self.viewModel = viewModel
        _part = State(initialValue: opensOn)
        _library = State(initialValue: viewModel.audio.makeMusicLibrary())
    }

    private var isReplacing: Bool { viewModel.audio.musicReplacementID != nil }
    private var shown: Part { isReplacing ? .music : part }

    private var title: String {
        isReplacing ? String(localized: "Replace music") : String(localized: "Add music or a sound")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SheetHeader(title: title)
                .padding(.horizontal, 16)
            if !isReplacing {
                Picker(String(localized: "Add"), selection: $part) {
                    Text("Music").tag(Part.music)
                    Text("Sound effects").tag(Part.effects)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .padding(.horizontal, 16)
                .accessibilityIdentifier("edit.addSoundPart")
            }
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    switch shown {
                    case .music: music
                    case .effects: SoundEffectsSection(viewModel: viewModel) { dismiss() }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
            .scrollBounceBehavior(.basedOnSize)
            .scrollDismissesKeyboard(.interactively)
        }
        .padding(.top, 8)
        .fileImporter(isPresented: $picksFile, allowedContentTypes: [.audio]) { result in
            guard case .success(let url) = result else { return }
            Task {
                await viewModel.audio.importMusic(from: url)
                if viewModel.selectedMusicID != nil { dismiss() }
            }
        }
        .onChange(of: part) { library.stop(); viewModel.audio.soundPreviews.stop() }
        .onDisappear { library.stop() }
        .cueSheetChrome()
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    // MARK: - Music

    private var music: some View {
        VStack(alignment: .leading, spacing: 12) {
            SearchField(text: $library.query, prompt: "Search music", isFocused: $isSearching)
                .accessibilityIdentifier("edit.library.search")
            // The creator's own music, before Cue's 20 tracks (it was under them).
            filesButton
            PanelChips(
                options: MusicLibraryFilter.allCases.map { PanelOption($0, $0.label, key: $0.id) },
                selection: library.filter, identifier: "edit.library.filter"
            ) { library.filter = $0 }
            PanelRowLabel(label: String(localized: "Made by Cue"), detail: String(localized: "Free to use in your videos"))
            let tracks = library.tracks
            if tracks.isEmpty {
                Text("No track matches · Try another word or filter")
                    .font(.footnote)
                    .foregroundStyle(Palette.ink2)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityIdentifier("edit.library.empty")
            }
            LazyVStack(spacing: 8) {
                ForEach(tracks) { track in
                    MusicTrackRow(library: library, track: track) {
                        Task {
                            if await library.add(track) { dismiss() }
                        }
                    }
                }
            }
            Text("From Files. Use only music you own or have the rights to. Songs from Apple Music can’t be added.")
                .font(.footnote)
                .foregroundStyle(Palette.ink2)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    /// A sound file from Files, copied into the app and laid under the voice.
    private var filesButton: some View {
        Button {
            library.stop()
            picksFile = true
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "folder")
                    .font(.editorGlyph(EditorGlyph.control, weight: .semibold))
                    .foregroundStyle(Palette.Editor.laneMusicInk)
                    .frame(width: 38, height: 38)
                    .background(Palette.Editor.laneMusic, in: RoundedRectangle(cornerRadius: Metrics.editorInsetRadius, style: .continuous))
                VStack(alignment: .leading, spacing: 2) {
                    Text("Browse Files")
                        .font(.system(.subheadline, weight: .semibold))
                    Text("MP3, M4A, WAV or AIFF")
                        .font(.caption)
                        .foregroundStyle(Palette.ink2)
                }
                Spacer()
                if viewModel.audio.isImportingMusic && library.adding == nil {
                    ProgressView().tint(Palette.ink)
                } else {
                    Image(systemName: "plus")
                        .font(.editorGlyph(EditorGlyph.control, weight: .semibold))
                        .foregroundStyle(Palette.accText)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .editorCard()
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(viewModel.audio.isImportingMusic)
        .accessibilityIdentifier("edit.addMusicButton")
    }
}
