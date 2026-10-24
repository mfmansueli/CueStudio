//
//  AddMusicSheet.swift
//  Cue Studio
//

import SwiftUI
import UniformTypeIdentifiers

/// "Add music or a sound": Cue's sound effects (made by Cue, free to use in any video: tap one to hear it, + to add it at the
/// playhead, over music too), and a sound file from Files, copied into the app and laid under the voice. The note says why
/// songs from Apple Music can't be picked (they have no readable track).
struct AddMusicSheet: View {
    let viewModel: QuickEditViewModel

    @Environment(\.dismiss) private var dismiss
    @State private var picksFile = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            SheetHeader(title: String(localized: "Add music or a sound"))
                .padding(.horizontal, 16)
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    effects
                    filesButton
                    Text("From Files. Use only music you own or have the rights to. Songs from Apple Music can’t be added.")
                        .font(.footnote)
                        .foregroundStyle(Palette.ink2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
        .padding(.top, 8)
        .fileImporter(isPresented: $picksFile, allowedContentTypes: [.audio]) { result in
            guard case .success(let url) = result else { return }
            Task {
                await viewModel.audio.importMusic(from: url)
                if viewModel.selectedMusicID != nil { dismiss() }
            }
        }
        .onDisappear { viewModel.audio.soundPreviews.stop() }
        .cueSheetChrome()
        .presentationDetents([.height(600 + Metrics.sheetBarHeight), .large])
        .presentationDragIndicator(.visible)
    }

    /// A sound file from Files, copied into the app and laid under the voice.
    private var filesButton: some View {
        Button { picksFile = true } label: {
            HStack(spacing: 12) {
                Image(systemName: viewModel.audio.isImportingMusic ? "hourglass" : "music.note")
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
                if viewModel.audio.isImportingMusic {
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

    /// Cue's sound effects in two columns, so each name and what it's for read whole: tap to hear, + to add at the playhead.
    private var effects: some View {
        VStack(alignment: .leading, spacing: 8) {
            PanelRowLabel(label: String(localized: "Sound effects"), detail: String(localized: "Made by Cue · free to use in your videos"))
            Grid(horizontalSpacing: 8, verticalSpacing: 8) {
                ForEach(Array(stride(from: 0, to: SoundEffect.allCases.count, by: 2)), id: \.self) { index in
                    GridRow {
                        effectCell(SoundEffect.allCases[index])
                        if index + 1 < SoundEffect.allCases.count {
                            effectCell(SoundEffect.allCases[index + 1])
                        } else {
                            Color.clear.gridCellUnsizedAxes([.horizontal, .vertical])
                        }
                    }
                }
            }
        }
    }

    /// The name and what it's for (tap to hear) and a separate + (add at the playhead), as tall as the row's tallest.
    private func effectCell(_ effect: SoundEffect) -> some View {
        HStack(spacing: 0) {
            Button { viewModel.audio.soundPreviews.play(effect) } label: {
                HStack(spacing: 10) {
                    Image(systemName: effect.systemImage)
                        .font(.system(.subheadline, weight: .semibold))
                        .frame(minWidth: 20)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(effect.label)
                            .font(.system(.subheadline, weight: .semibold))
                            .lineLimit(2)
                        Text(effect.use)
                            .font(.caption)
                            .foregroundStyle(Palette.ink2)
                            .lineLimit(2)
                    }
                    .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 0)
                }
                .padding(.leading, 12)
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity, minHeight: 52, maxHeight: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text("Hear \(effect.label)"))
            .accessibilityIdentifier("edit.effect.play.\(effect.rawValue)")
            Button {
                viewModel.audio.addSoundEffect(effect)
                dismiss()
            } label: {
                Image(systemName: "plus")
                    .font(.system(.body, weight: .bold))
                    .foregroundStyle(Palette.accText)
                    .frame(width: Metrics.hitTarget)
                    .frame(maxHeight: .infinity)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text("Add \(effect.label)"))
            .accessibilityIdentifier("edit.effect.add.\(effect.rawValue)")
        }
        .foregroundStyle(Palette.ink)
        .frame(maxHeight: .infinity)
        .editorCard()
    }
}
