//
//  VoiceOverToolView.swift
//  Cue Studio
//

import SwiftUI

/// Voice-over: play, time, undo and redo; the voice track; then Record (from the playhead, the
/// video playing silent) and Stop. After a recording: Keep, Redo and Delete, and its volume. A
/// voice-over picked on the track shows its volume and Delete.
struct VoiceOverToolView: View {
    let viewModel: QuickEditViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            QuickEditTransportBar(viewModel: viewModel)
                .disabled(viewModel.isRecordingVoiceOver)
            LayerTrackView(viewModel: viewModel, bars: viewModel.voiceOverBars, tint: Palette.success, identifier: "edit.voiceTrack")
                .disabled(viewModel.isRecordingVoiceOver)
            if viewModel.isRecordingVoiceOver {
                stopButton
            } else if let clip = viewModel.reviewedVoiceOver {
                review(clip)
            } else {
                recordButton
                Text(viewModel.edit.voiceOvers.isEmpty
                    ? String(localized: "Records from the playhead while the video plays silent")
                    : String(localized: "Tap a voice-over's bar to change its volume"))
                    .font(.caption)
                    .foregroundStyle(Palette.ink.opacity(0.45))
                    .lineLimit(1)
            }
        }
        .onChange(of: viewModel.player.isPlaying) { _, isPlaying in
            // The end of the video ends the recording.
            if !isPlaying, viewModel.isRecordingVoiceOver { viewModel.stopVoiceOver() }
        }
    }

    private var recordButton: some View {
        Button {
            Task { await viewModel.startVoiceOver() }
        } label: {
            Label("Record", systemImage: "mic.fill")
        }
        .buttonStyle(.cueLight(.medium))
        .accessibilityIdentifier("edit.recordVoiceOverButton")
    }

    private var stopButton: some View {
        Button { viewModel.stopVoiceOver() } label: {
            HStack(spacing: 8) {
                Image(systemName: "stop.fill")
                Text("Stop · \(viewModel.recordingElapsedLabel)").monospacedDigit()
            }
        }
        .buttonStyle(.cueDestructive(.medium))
        .accessibilityIdentifier("edit.stopVoiceOverButton")
    }

    private func review(_ clip: VoiceOverClip) -> some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                Button("Keep") { viewModel.keepVoiceOver() }
                    .buttonStyle(.cueLight(.medium))
                    .accessibilityIdentifier("edit.keepVoiceOverButton")
                Button {
                    Task { await viewModel.redoVoiceOver() }
                } label: {
                    Label("Redo", systemImage: "arrow.counterclockwise")
                }
                .buttonStyle(.cueSecondary(.medium, expands: false))
                .accessibilityIdentifier("edit.redoVoiceOverButton")
                Button { viewModel.deleteVoiceOver(clip.id) } label: {
                    Image(systemName: "trash")
                }
                .buttonStyle(.cueIcon(.danger, diameter: Metrics.mediumButtonHeight))
                .accessibilityLabel(Text("Delete voice-over"))
                .accessibilityIdentifier("edit.deleteVoiceOverButton")
            }
            HStack(spacing: 10) {
                Image(systemName: "speaker.wave.2").foregroundStyle(Palette.ink2)
                Slider(
                    value: Binding(
                        get: { clip.volume },
                        set: { viewModel.setVoiceOverVolume(clip.id, volume: $0) }
                    ),
                    in: VoiceOverClip.volumeRange,
                    onEditingChanged: { editing in editing ? viewModel.beginChange() : viewModel.endChange() }
                )
                .tint(Palette.acc)
                .accessibilityLabel(Text("Voice-over volume"))
                .accessibilityIdentifier("edit.voiceOverVolume")
                Text(clip.volume.formatted(.percent.precision(.fractionLength(0)).locale(.interface)))
                    .font(.footnote.monospacedDigit())
                    .foregroundStyle(Palette.ink2)
                    .fixedSize()
                    .frame(minWidth: 44, alignment: .trailing)
            }
        }
    }
}
