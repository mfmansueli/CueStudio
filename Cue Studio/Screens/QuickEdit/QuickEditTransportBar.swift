//
//  QuickEditTransportBar.swift
//  Cue Studio
//

import SwiftUI

/// Under the preview: play / pause and "00:04.32 / 00:11.00" in every tool, plus undo and redo of
/// the timeline in Trim. It reads the player's clock, so it redraws while the video plays and the
/// rest of the screen doesn't.
struct QuickEditTransportBar: View {
    let viewModel: QuickEditViewModel

    var body: some View {
        let isPlaying = viewModel.player.isPlaying
        HStack(spacing: 10) {
            Button(action: viewModel.togglePlayback) {
                Image(systemName: isPlaying ? "pause.fill" : "play.fill")
            }
            .buttonStyle(.cueIcon(.surface, diameter: 36))
            .disabled(!viewModel.isReady)
            .accessibilityLabel(isPlaying ? Text("Pause") : Text("Play"))
            .accessibilityIdentifier("edit.playButton")
            Text(viewModel.timeLabel)
                .font(.footnote.monospacedDigit())
                .foregroundStyle(Palette.ink2)
                .accessibilityLabel(Text("Time"))
                .accessibilityValue(Text(viewModel.timeLabel))
                .accessibilityIdentifier("edit.timeLabel")
            Spacer(minLength: 0)
            if viewModel.tool == .trim {
                Button(action: viewModel.undo) {
                    Image(systemName: "arrow.uturn.backward")
                }
                .buttonStyle(.cueIcon(.surface, diameter: 36))
                .disabled(!viewModel.canUndo)
                .accessibilityLabel(Text("Undo"))
                .accessibilityIdentifier("edit.undoButton")
                Button(action: viewModel.redo) {
                    Image(systemName: "arrow.uturn.forward")
                }
                .buttonStyle(.cueIcon(.surface, diameter: 36))
                .disabled(!viewModel.canRedo)
                .accessibilityLabel(Text("Redo"))
                .accessibilityIdentifier("edit.redoButton")
            }
        }
        .frame(height: Metrics.hitTarget)
    }
}
