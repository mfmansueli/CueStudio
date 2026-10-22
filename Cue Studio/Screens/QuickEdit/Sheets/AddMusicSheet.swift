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
            effects
            Button { picksFile = true } label: {
                HStack(spacing: 12) {
                    Image(systemName: viewModel.isImportingMusic ? "hourglass" : "music.note")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(Palette.Editor.laneMusicInk)
                        .frame(width: 38, height: 38)
                        .background(Palette.Editor.laneMusic, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Browse Files")
                            .font(.system(size: 15, weight: .semibold))
                        Text("MP3, M4A, WAV or AIFF")
                            .font(.system(size: 12.5))
                            .foregroundStyle(Palette.ink2)
                    }
                    Spacer()
                    if viewModel.isImportingMusic {
                        ProgressView().tint(Palette.ink)
                    } else {
                        Image(systemName: "plus")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(Palette.accText)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(Palette.Editor.panelCard, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(viewModel.isImportingMusic)
            .accessibilityIdentifier("edit.addMusicButton")
            Text("From Files. Use only music you own or have the rights to. Songs from Apple Music can’t be added.")
                .font(.system(size: 12.5))
                .foregroundStyle(Palette.ink2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 24)
        .fileImporter(isPresented: $picksFile, allowedContentTypes: [.audio]) { result in
            guard case .success(let url) = result else { return }
            Task {
                await viewModel.importMusic(from: url)
                if viewModel.selectedMusicID != nil { dismiss() }
            }
        }
        .onDisappear { viewModel.soundPreviews.stop() }
        .cueSheetChrome()
        .presentationDetents([.height(480 + Metrics.sheetBarHeight), .large])
        .presentationDragIndicator(.visible)
    }

    /// Cue's sound effects: tap to hear, + to add at the playhead.
    private var effects: some View {
        VStack(alignment: .leading, spacing: 8) {
            PanelRowLabel(label: String(localized: "Sound effects"), detail: String(localized: "Made by Cue · free to use in your videos"))
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 104), spacing: 8)], spacing: 8) {
                ForEach(SoundEffect.allCases) { effect in
                    HStack(spacing: 0) {
                        Button { viewModel.soundPreviews.play(effect) } label: {
                            HStack(spacing: 8) {
                                Image(systemName: effect.systemImage).font(.system(size: 14, weight: .semibold)).frame(width: 18)
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(effect.label).font(.system(size: 14, weight: .semibold)).lineLimit(1).minimumScaleFactor(0.8)
                                    Text(effect.use).font(.system(size: 11)).foregroundStyle(Palette.ink2).lineLimit(1).minimumScaleFactor(0.8)
                                }
                                Spacer(minLength: 0)
                            }
                            .padding(.leading, 10)
                            .frame(maxWidth: .infinity, minHeight: 52, alignment: .leading)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(Text("Hear \(effect.label)"))
                        .accessibilityIdentifier("edit.effect.play.\(effect.rawValue)")
                        Button {
                            viewModel.addSoundEffect(effect)
                            dismiss()
                        } label: {
                            Image(systemName: "plus")
                                .font(.system(size: 15, weight: .bold))
                                .foregroundStyle(Palette.accText)
                                .frame(width: Metrics.hitTarget, height: 52)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(Text("Add \(effect.label)"))
                        .accessibilityIdentifier("edit.effect.add.\(effect.rawValue)")
                    }
                    .foregroundStyle(Palette.ink)
                    .background(Palette.Editor.panelCard, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
            }
        }
    }
}
