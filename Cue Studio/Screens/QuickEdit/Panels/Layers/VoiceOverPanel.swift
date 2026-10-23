//
//  VoiceOverPanel.swift
//  Cue Studio
//

import SwiftUI

/// Voice-over: one big button. It records from the playhead while the video plays without sound
/// (the circle turns into a square), and the track grows in red; Stop leaves an orange item where
/// it started. The end of the video stops it too. With a script, Record sits beside its label, and
/// under it "Show script" (the script over the preview while recording) and, when on, its speed.
struct VoiceOverPanel: View {
    @Bindable var viewModel: QuickEditViewModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        PanelFrame(viewModel: viewModel, panel: .voiceOver) {
            if viewModel.audio.offersNarrationScript {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 14) {
                        recordButton
                        VStack(alignment: .leading, spacing: 2) {
                            recordLabel
                            VoiceOverClock(viewModel: viewModel)
                        }
                        Spacer(minLength: 0)
                    }
                    PanelToggleRow(
                        label: String(localized: "Show script"),
                        detail: String(localized: "On your screen while you record · not in the video"),
                        isOn: viewModel.audio.showsNarrationScript,
                        identifier: "edit.voiceOverScriptToggle",
                        onToggle: viewModel.audio.toggleNarrationScript
                    )
                    if viewModel.audio.showsNarrationScript {
                        SpeedSlider(speed: viewModel.audio.narrationPace.speed) { viewModel.audio.setNarrationSpeed($0) }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                VStack(spacing: 10) {
                    recordButton
                    recordLabel
                    VoiceOverClock(viewModel: viewModel)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 4)
            }
        }
    }

    private var recordButton: some View {
        let isRecording = viewModel.audio.isRecordingVoiceOver
        return Button {
            if isRecording {
                viewModel.audio.stopVoiceOver()
            } else {
                Task { await viewModel.audio.startVoiceOver() }
            }
        } label: {
            ZStack {
                Circle().strokeBorder(Palette.ink, lineWidth: 4).frame(width: 72, height: 72)
                // A dot that turns into a stop square while recording.
                let side: CGFloat = isRecording ? 26 : 54
                RoundedRectangle(cornerRadius: isRecording ? Metrics.recordStopRadius : side / 2, style: .continuous)
                    .fill(Palette.danger)
                    .frame(width: side, height: side)
            }
            .frame(width: 80, height: 80)
            .contentShape(Circle())
            .animation(reduceMotion ? nil : .easeInOut(duration: 0.2), value: isRecording)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isRecording ? Text("Stop recording") : Text("Record a voice-over"))
        .accessibilityIdentifier(isRecording ? "edit.stopVoiceOverButton" : "edit.recordVoiceOverButton")
    }

    private var recordLabel: some View {
        Text(viewModel.audio.isRecordingVoiceOver ? "Stop" : "Record").font(.system(.subheadline, weight: .semibold))
    }
}
