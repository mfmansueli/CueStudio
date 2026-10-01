//
//  EditorPlayerBar.swift
//  Cue Studio
//

import SwiftUI

/// Under the preview: "00:01.2 / 00:21.6", play / pause in the middle, and undo, redo and full
/// screen, always within reach (also space, ⌘Z and ⇧⌘Z on a keyboard). It reads the player's
/// clock, so it redraws while the video plays and the rest of the screen doesn't.
struct EditorPlayerBar: View {
    let viewModel: QuickEditViewModel

    var body: some View {
        let isPlaying = viewModel.player.isPlaying
        ZStack {
            HStack(spacing: 2) {
                Text(timeText)
                    .font(.system(size: 13, weight: .semibold).monospacedDigit())
                    .lineLimit(1)
                    .accessibilityLabel(Text("Time"))
                    .accessibilityValue(Text(viewModel.timeLabel))
                    .accessibilityIdentifier("edit.timeLabel")
                Spacer(minLength: 0)
                iconButton("arrow.uturn.backward", label: Text("Undo"), id: "edit.undoButton", enabled: viewModel.canUndo, action: viewModel.undo)
                    .keyboardShortcut("z", modifiers: .command)
                iconButton("arrow.uturn.forward", label: Text("Redo"), id: "edit.redoButton", enabled: viewModel.canRedo, action: viewModel.redo)
                    .keyboardShortcut("z", modifiers: [.command, .shift])
                iconButton(
                    "arrow.up.left.and.arrow.down.right", label: Text("Full screen"), id: "edit.fullScreenButton", enabled: viewModel.isReady
                ) {
                    viewModel.toggleFullScreen()
                }
            }
            Button(action: viewModel.togglePlayback) {
                Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 22))
                    .foregroundStyle(Palette.ink)
                    .frame(width: Metrics.hitTarget, height: Metrics.hitTarget)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(!viewModel.isReady || viewModel.isRecordingVoiceOver)
            // Space plays, unless a field could be taking the keyboard.
            .keyboardShortcut(viewModel.acceptsSpaceToPlay ? KeyboardShortcut(.space, modifiers: []) : nil)
            .accessibilityLabel(isPlaying ? Text("Pause") : Text("Play"))
            .accessibilityIdentifier("edit.playButton")
        }
        .padding(.leading, 16)
        .padding(.trailing, 10)
        .dynamicTypeSize(...DynamicTypeSize.accessibility1)
    }

    /// The playhead bright, the length dimmed.
    private var timeText: AttributedString {
        var current = AttributedString(viewModel.currentTimeLabel)
        current.foregroundColor = Palette.ink
        var total = AttributedString(" / " + viewModel.durationLabel)
        total.foregroundColor = Palette.ink2
        return current + total
    }

    private func iconButton(_ systemImage: String, label: Text, id: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(Palette.ink)
                .opacity(enabled ? 1 : 0.3)
                .frame(width: 40, height: Metrics.hitTarget)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .accessibilityLabel(label)
        .accessibilityIdentifier(id)
    }
}
