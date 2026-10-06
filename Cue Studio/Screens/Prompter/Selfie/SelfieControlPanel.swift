//
//  SelfieControlPanel.swift
//  Cue Studio
//

import SwiftUI

/// One toolbar for prompter and camera, in night glass, for Selfie. Ready to record it is whole: the mode switch
/// with back to the top, play and Aa, the speed (or what Voice Following is doing), the HUD line
/// with the microphone and the setup the take records with, and the capture row. While a take
/// records it shrinks to `RecordingCompactBar`; a tap on the screen brings the whole one back for
/// a few seconds.
struct SelfieControlPanel: View {
    let viewModel: PrompterViewModel

    @Environment(SessionSetupService.self) private var session
    @Environment(AudioInputManager.self) private var audio

    var body: some View {
        let compact = viewModel.showsCompactBar
        let shape = RoundedRectangle(cornerRadius: 40, style: .continuous)
        VStack(spacing: 10) {
            if compact {
                RecordingCompactBar(viewModel: viewModel)
                    .transition(.opacity)
            } else {
                if viewModel.hasScript { scriptRows } else { freestyleRow }
                hudLine
                captureRow
                    .padding(.horizontal, 6)
                    .padding(.top, 2)
                    .transition(.opacity)
            }
        }
        .padding(EdgeInsets(top: 12, leading: 12, bottom: compact ? 16 : 20, trailing: 12))
        .background(.ultraThinMaterial, in: shape)
        .glassNight(in: shape, density: .solid)
        .animation(.smooth(duration: 0.25), value: compact)
        // Using a control of the whole bar while recording keeps it open a little longer: the controls say so themselves
        // (`PrompterViewModel.setScrollMode`, `setSpeed`, `togglePlay`, `rewind`). A gesture over the whole panel took the touches of
        // the system's controls in it (Voice | Steady and the speed slider stopped responding).
    }

    // MARK: - Rows

    /// The mode switch and the playback buttons, then the speed (Steady) or the voice line.
    private var scriptRows: some View {
        VStack(spacing: 10) {
            HStack(spacing: 8) {
                ScrollModePicker(selection: session.prompter.scrollMode) { viewModel.setScrollMode($0) }
                Button { viewModel.rewind() } label: { Image(systemName: "arrow.up.to.line") }
                    .glassIconButton()
                    .accessibilityLabel(Text("Back to the top"))
                Button { viewModel.togglePlay() } label: {
                    Image(systemName: viewModel.isPlaying ? "pause.fill" : "play.fill")
                }
                .glassIconButton()
                .accessibilityLabel(Text(viewModel.isPlaying ? "Pause" : "Play"))
                .accessibilityIdentifier("prompter.playButton")
                Button { viewModel.sheet = .display } label: {
                    Text("Aa").font(.system(size: 15, weight: .semibold))
                }
                .glassIconButton()
                .accessibilityLabel(Text("Display settings"))
                .accessibilityIdentifier("prompter.displayButton")
            }
            .frame(height: Metrics.hitTarget)
            if session.prompter.scrollMode == .voice {
                VoiceIndicator(
                    level: viewModel.voiceLevel, isListening: viewModel.isPlaying && viewModel.isVoiceActive,
                    status: viewModel.voiceFollowStatus, speedLabel: session.prompter.speedLabel
                )
            } else {
                SpeedSlider(
                    speed: session.prompter.speed,
                    onChange: { viewModel.setSpeed($0) }
                )
            }
        }
    }

    private var freestyleRow: some View {
        HStack {
            VStack(alignment: .leading, spacing: 1) {
                Text("Freestyle").font(.subheadline.weight(.semibold))
                Text("Freestyle · Add a script anytime")
                    .font(.caption)
                    .foregroundStyle(Palette.ink2)
            }
            Spacer()
            Button {
                viewModel.sheet = .addScript
            } label: {
                Label("Add script", systemImage: "plus")
            }
            .buttonStyle(.cuePrimary(.compact, expands: false))
            .disabled(viewModel.isRecording)
            .accessibilityIdentifier("prompter.addScriptButton")
        }
        .padding(.leading, 6)
        .frame(height: Metrics.hitTarget)
    }

    /// The HUD line: "● IPHONE MIC · 1080P 30 · 9:16 ›". The microphone and the setup are two buttons.
    private var hudLine: some View {
        HStack(spacing: 6) {
            AudioInputPill(isEnabled: viewModel.canChangeAudioInput) { viewModel.openAudioInput() }
                .layoutPriority(1)
            Text("·")
                .font(CueStudioFont.hud)
                .foregroundStyle(Palette.ink3)
                .accessibilityHidden(true)
            SetupSummaryPill(
                summary: viewModel.captureSummary,
                source: viewModel.session.captureSource,
                isEnabled: viewModel.canChangeSetup,
                action: { viewModel.openRecordingSetup() }
            )
            .layoutPriority(2)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 28)
    }

    /// Last take with how many there are, camera settings, record, flip and the "•••" menu.
    private var captureRow: some View {
        HStack {
            LastTakeButton(viewModel: viewModel)
            Spacer()
            Button { viewModel.sheet = .camera } label: { Image(systemName: "slider.horizontal.3") }
                .glassIconButton()
                .disabled(viewModel.isRecording)
                .accessibilityLabel(Text("Camera settings"))
                .accessibilityIdentifier("prompter.cameraSettingsButton")
            Spacer()
            RecordButton(isRecording: viewModel.isRecording, isCountingDown: viewModel.countdown != nil) {
                Task { await viewModel.recordButtonTapped() }
            }
            // No microphone, no recording: the card above says why.
            .disabled(!audio.isMicrophoneAllowed && !viewModel.isRecording)
            .opacity(!audio.isMicrophoneAllowed && !viewModel.isRecording ? 0.4 : 1)
            Spacer()
            Button { viewModel.flipCamera() } label: { Image(systemName: "arrow.triangle.2.circlepath.camera") }
                .glassIconButton()
                .disabled(viewModel.isRecording)
                .accessibilityLabel(Text("Switch camera"))
            Spacer()
            RecorderMoreMenu(viewModel: viewModel)
        }
    }
}
