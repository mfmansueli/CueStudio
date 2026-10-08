//
//  SelfieControlParts.swift
//  Cue Studio
//

import SwiftUI

/// The Selfie panel's controls as separate pieces, which the sheet (`SelfieControlSheet`) arranges.
@MainActor
struct SelfieControlParts {
    let viewModel: PrompterViewModel
    let session: SessionSetupService
    let audio: AudioInputManager

    // MARK: - Reading

    var modePicker: some View {
        ScrollModePicker(selection: session.prompter.scrollMode) { viewModel.setScrollMode($0) }
    }

    var rewindButton: some View {
        Button { viewModel.rewind() } label: { Image(systemName: "arrow.up.to.line") }
            .glassIconButton()
            .accessibilityLabel(Text("Back to the top"))
    }

    var playButton: some View {
        Button { viewModel.togglePlay() } label: {
            Image(systemName: viewModel.isPlaying ? "pause.fill" : "play.fill")
        }
        .glassIconButton()
        .accessibilityLabel(Text(viewModel.isPlaying ? "Pause" : "Play"))
        .accessibilityIdentifier("prompter.playButton")
    }

    var displayButton: some View {
        Button { viewModel.sheet = .display } label: {
            Text("Aa").font(.system(size: 15, weight: .semibold))
        }
        .glassIconButton()
        .accessibilityLabel(Text("Display settings"))
        .accessibilityIdentifier("prompter.displayButton")
    }

    /// The speed (Steady) or what Voice Following is doing (Voice).
    @ViewBuilder
    var speedBlock: some View {
        if session.prompter.scrollMode == .voice {
            VoiceIndicator(
                level: viewModel.voiceLevel, isListening: viewModel.isPlaying && viewModel.isVoiceActive,
                status: viewModel.voiceFollowStatus, speedLabel: session.prompter.speedLabel
            )
        } else {
            SpeedSlider(speed: session.prompter.speed, onChange: { viewModel.setSpeed($0) })
        }
    }

    /// With no script the reading controls give way to this.
    var freestyleRow: some View {
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

    // MARK: - Microphone and setup

    var audioPill: some View {
        AudioInputPill(isEnabled: viewModel.canChangeAudioInput) { viewModel.openAudioInput() }
            .layoutPriority(1)
    }

    var setupPill: some View {
        SetupSummaryPill(
            summary: viewModel.captureSummary,
            source: viewModel.session.captureSource,
            isEnabled: viewModel.canChangeSetup,
            action: { viewModel.openRecordingSetup() }
        )
        .layoutPriority(2)
    }

    /// The two pills with their dot between, without a frame of their own.
    var hudPills: some View {
        HStack(spacing: 6) {
            audioPill
            Text("·")
                .font(CueStudioFont.hud)
                .foregroundStyle(Palette.ink3)
                .accessibilityHidden(true)
            setupPill
        }
    }

    /// "● IPHONE MIC · 1080P 30 · 9:16 ›" as a line of its own.
    var hudLine: some View {
        hudPills
            .frame(maxWidth: .infinity)
            .frame(height: 28)
    }

    // MARK: - Capture

    var lastTakeButton: some View {
        LastTakeButton(viewModel: viewModel)
    }

    var cameraSettingsButton: some View {
        Button { viewModel.sheet = .camera } label: { Image(systemName: "slider.horizontal.3") }
            .glassIconButton()
            .disabled(viewModel.isRecording)
            .accessibilityLabel(Text("Camera settings"))
            .accessibilityIdentifier("prompter.cameraSettingsButton")
    }

    /// No microphone, no recording: the card above the panel says why.
    var recordButton: some View {
        RecordButton(isRecording: viewModel.isRecording, isCountingDown: viewModel.countdown != nil) {
            Task { await viewModel.recordButtonTapped() }
        }
        .disabled(!audio.isMicrophoneAllowed && !viewModel.isRecording)
        .opacity(!audio.isMicrophoneAllowed && !viewModel.isRecording ? 0.4 : 1)
    }

    var flipButton: some View {
        Button { viewModel.flipCamera() } label: { Image(systemName: "arrow.triangle.2.circlepath.camera") }
            .glassIconButton()
            .disabled(viewModel.isRecording)
            .accessibilityLabel(Text("Switch camera"))
    }

    var moreMenu: some View {
        RecorderMoreMenu(viewModel: viewModel)
    }
}
