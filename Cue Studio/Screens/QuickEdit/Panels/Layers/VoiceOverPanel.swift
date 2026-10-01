//
//  VoiceOverPanel.swift
//  Cue Studio
//

import SwiftUI

/// Voice-over: one big button. It records from the playhead while the video plays without sound
/// (the circle turns into a square), and the track grows in red; Stop leaves an orange item where
/// it started. The end of the video stops it too.
struct VoiceOverPanel: View {
    @Bindable var viewModel: QuickEditViewModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let isRecording = viewModel.isRecordingVoiceOver
        PanelFrame(viewModel: viewModel, panel: .voiceOver) {
            VStack(spacing: 10) {
                Button {
                    if isRecording {
                        viewModel.stopVoiceOver()
                    } else {
                        Task { await viewModel.startVoiceOver() }
                    }
                } label: {
                    ZStack {
                        Circle().strokeBorder(Color.white, lineWidth: 4).frame(width: 72, height: 72)
                        RoundedRectangle(cornerRadius: isRecording ? 7 : 27, style: .continuous)
                            .fill(Palette.danger)
                            .frame(width: isRecording ? 26 : 54, height: isRecording ? 26 : 54)
                    }
                    .frame(width: 80, height: 80)
                    .contentShape(Circle())
                    .animation(reduceMotion ? nil : .easeInOut(duration: 0.2), value: isRecording)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(isRecording ? Text("Stop recording") : Text("Record a voice-over"))
                .accessibilityIdentifier(isRecording ? "edit.stopVoiceOverButton" : "edit.recordVoiceOverButton")
                Text(isRecording ? "Stop" : "Record").font(.system(.subheadline, weight: .semibold))
                VoiceOverClock(viewModel: viewModel)
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 4)
        }
        .onChange(of: viewModel.player.isPlaying) { _, isPlaying in
            // The end of the video ends the recording.
            if !isPlaying, viewModel.isRecordingVoiceOver { viewModel.stopVoiceOver() }
        }
    }
}
