//
//  EditorPlayerBar.swift
//  Cue Studio
//

import SwiftUI

/// Under the preview: "00:01.2 / 00:21.6", play / pause in the middle between ‹ › (one frame back or forward, held to repeat),
/// and undo, redo and full screen, always within reach (also space, ⌘Z and ⇧⌘Z on a keyboard). It reads the player's
/// clock, so it redraws while the video plays and the rest of the screen doesn't.
struct EditorPlayerBar: View {
    let viewModel: QuickEditViewModel
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        let isPlaying = viewModel.player.isPlaying
        ZStack {
            HStack(spacing: 2) {
                Text(timeText)
                    .font(.system(.footnote, weight: .semibold).monospacedDigit())
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    // The bar keeps its height: the time grows up to the largest size it fits.
                    .dynamicTypeSize(...DynamicTypeSize.xxLarge)
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
            HStack(spacing: 0) {
                if showsFrameSteps { frameStep(-1) }
                Button(action: viewModel.togglePlayback) {
                    Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                        .symbolSwap(value: isPlaying)
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
                if showsFrameSteps { frameStep(1) }
            }
            // Time runs left to right in every language (media never mirrors): ‹ back a frame stays on the left in Arabic too.
            .environment(\.layoutDirection, .leftToRight)
        }
        .padding(.leading, 16)
        .padding(.trailing, 10)
        .dynamicTypeSize(...DynamicTypeSize.accessibility1)
    }

    /// ‹ › one frame (`QuickEditViewModel.stepFrame`), while there is room beside the time and the undo buttons.
    private var showsFrameSteps: Bool { typeSize < .xxLarge }

    private func frameStep(_ direction: Int) -> some View {
        Button { viewModel.stepFrame(direction) } label: {
            Image(systemName: direction < 0 ? "chevron.left" : "chevron.right")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Palette.ink)
                .opacity(viewModel.isReady ? 1 : Metrics.disabledOpacity)
                .frame(width: 34, height: Metrics.hitTarget)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .buttonRepeatBehavior(.enabled)
        .disabled(!viewModel.isReady || viewModel.isRecordingVoiceOver)
        .accessibilityLabel(direction < 0 ? Text("Previous frame") : Text("Next frame"))
        .accessibilityIdentifier(direction < 0 ? "edit.previousFrame" : "edit.nextFrame")
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
                .opacity(enabled ? 1 : Metrics.disabledOpacity)
                .frame(width: 40, height: Metrics.hitTarget)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .accessibilityLabel(label)
        .accessibilityIdentifier(id)
    }
}
