//
//  QuickEditTransportBar.swift
//  Cue Studio
//

import SwiftUI

/// The top row of Trim and Clean Up: play / pause, "00:04.32 / 00:11.00", undo and redo. It reads
/// the player's clock, so it redraws while the video plays and the rest of the panel doesn't.
struct QuickEditTransportBar: View {
    let viewModel: QuickEditViewModel

    var body: some View {
        let isPlaying = viewModel.player.isPlaying
        HStack(spacing: 10) {
            Button(action: viewModel.togglePlayback) {
                Image(systemName: isPlaying ? "pause.fill" : "play.fill")
            }
            .buttonStyle(.cueIcon(.light, diameter: 36))
            .disabled(!viewModel.isReady)
            .accessibilityLabel(isPlaying ? Text("Pause") : Text("Play"))
            .accessibilityIdentifier("edit.playButton")
            Text(timeText)
                .font(.subheadline.weight(.semibold).monospacedDigit())
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityLabel(Text("Time"))
                .accessibilityValue(Text(viewModel.timeLabel))
                .accessibilityIdentifier("edit.timeLabel")
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
        .frame(height: Metrics.hitTarget)
    }

    /// The playhead bright, the length dimmed, in one text.
    private var timeText: AttributedString {
        var current = AttributedString(viewModel.currentTimeLabel)
        current.foregroundColor = Palette.ink
        var total = AttributedString(" / " + viewModel.durationLabel)
        total.foregroundColor = Palette.ink2
        return current + total
    }
}
