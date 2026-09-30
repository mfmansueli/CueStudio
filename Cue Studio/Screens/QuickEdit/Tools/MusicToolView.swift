//
//  MusicToolView.swift
//  Cue Studio
//

import SwiftUI
import UniformTypeIdentifiers

/// Music: play, time, undo and redo; the music track; then "Add music" (a sound file from Files,
/// copied into the app), with a note on rights. With a clip picked: its volume, fade in and out,
/// "Lower under voice" and Mute, and Remove.
struct MusicToolView: View {
    let viewModel: QuickEditViewModel

    @State private var picksFile = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            QuickEditTransportBar(viewModel: viewModel)
            LayerTrackView(viewModel: viewModel, bars: viewModel.musicBars, tint: Palette.music, identifier: "edit.musicTrack")
            if let clip = viewModel.selectedMusic {
                selectedActions(clip)
            } else {
                addButton
                Text("Use only music you own or have the rights to. Songs from Apple Music can’t be added.")
                    .font(.caption)
                    .foregroundStyle(Palette.ink.opacity(0.45))
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("edit.musicRightsNote")
            }
        }
        .fileImporter(isPresented: $picksFile, allowedContentTypes: [.audio]) { result in
            guard case .success(let url) = result else { return }
            Task { await viewModel.importMusic(from: url) }
        }
    }

    private var addButton: some View {
        Button { picksFile = true } label: {
            HStack(spacing: 8) {
                if viewModel.isImportingMusic {
                    ProgressView().tint(Palette.bg)
                } else {
                    Image(systemName: "music.note")
                }
                if viewModel.isImportingMusic {
                    Text("Adding…")
                } else {
                    Text("Add music")
                }
            }
        }
        .buttonStyle(.cueLight(.medium))
        .disabled(viewModel.isImportingMusic)
        .accessibilityIdentifier("edit.addMusicButton")
    }

    private func selectedActions(_ clip: MusicClip) -> some View {
        VStack(spacing: 6) {
            HStack(spacing: 8) {
                Toggle(isOn: Binding(get: { clip.ducksUnderVoice }, set: { viewModel.setMusicDucks(clip.id, $0) })) {
                    Text("Lower under voice").font(.subheadline)
                }
                .toggleStyle(.button)
                .buttonStyle(.cueSecondary(.compact, expands: false))
                .accessibilityIdentifier("edit.musicDucks")
                Toggle(isOn: Binding(get: { clip.isMuted }, set: { viewModel.setMusicMuted(clip.id, $0) })) {
                    Image(systemName: clip.isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                }
                .toggleStyle(.button)
                .buttonStyle(.cueSecondary(.compact, expands: false))
                .accessibilityLabel(Text("Mute"))
                .accessibilityIdentifier("edit.musicMute")
                Spacer(minLength: 0)
                Button { viewModel.deleteMusic(clip.id) } label: {
                    Image(systemName: "trash")
                }
                .buttonStyle(.cueIcon(.danger, diameter: 36))
                .accessibilityLabel(Text("Remove music"))
                .accessibilityIdentifier("edit.deleteMusicButton")
                Button { viewModel.selectedMusicID = nil } label: {
                    Image(systemName: "checkmark")
                }
                .buttonStyle(.cueIcon(.surface, diameter: 36))
                .accessibilityLabel(Text("Done with this music"))
            }
            row(
                String(localized: "Volume"), value: clip.volume, range: MusicClip.volumeRange,
                text: clip.volume.formatted(.percent.precision(.fractionLength(0)).locale(.interface)),
                identifier: "edit.musicVolume"
            ) { viewModel.setMusicVolume(clip.id, $0) }
            row(
                String(localized: "Fade in"), value: clip.fadeIn, range: MusicClip.fadeRange,
                text: seconds(clip.fadeIn), identifier: "edit.musicFadeIn"
            ) { viewModel.setMusicFadeIn(clip.id, $0) }
            row(
                String(localized: "Fade out"), value: clip.fadeOut, range: MusicClip.fadeRange,
                text: seconds(clip.fadeOut), identifier: "edit.musicFadeOut"
            ) { viewModel.setMusicFadeOut(clip.id, $0) }
        }
    }

    private func row(
        _ title: String, value: Double, range: ClosedRange<Double>, text: String, identifier: String,
        set: @escaping @MainActor @Sendable (Double) -> Void
    ) -> some View {
        HStack(spacing: 10) {
            Text(title)
                .font(.footnote)
                .foregroundStyle(Palette.ink2)
                .frame(minWidth: 64, alignment: .leading)
            Slider(
                value: Binding(get: { value }, set: set), in: range,
                onEditingChanged: { editing in editing ? viewModel.beginChange() : viewModel.endChange() }
            )
            .tint(Palette.acc)
            .accessibilityLabel(Text(title))
            .accessibilityValue(Text(text))
            .accessibilityIdentifier(identifier)
            Text(text)
                .font(.footnote.monospacedDigit())
                .foregroundStyle(Palette.ink2)
                .fixedSize()
                .frame(minWidth: 44, alignment: .trailing)
        }
    }

    private func seconds(_ value: TimeInterval) -> String {
        Measurement(value: value, unit: UnitDuration.seconds)
            .formatted(.measurement(width: .narrow, numberFormatStyle: .number.precision(.fractionLength(1))).locale(.interface))
    }
}
