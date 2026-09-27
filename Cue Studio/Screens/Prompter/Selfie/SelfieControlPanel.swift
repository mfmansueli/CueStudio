//
//  SelfieControlPanel.swift
//  Cue Studio
//

import SwiftUI

/// One toolbar for prompter and camera: scroll controls on top, capture controls below.
struct SelfieControlPanel: View {
    let viewModel: PrompterViewModel

    @Environment(PreferencesService.self) private var preferences

    var body: some View {
        VStack(spacing: 0) {
            if viewModel.hasScript { scriptRow } else { freestyleRow }
            Rectangle()
                .fill(Color.white.opacity(0.12))
                .frame(height: 0.5)
                .padding(EdgeInsets(top: 12, leading: 2, bottom: 10, trailing: 2))
            cameraRow
        }
        .padding(EdgeInsets(top: 12, leading: 14, bottom: 14, trailing: 14))
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 40, style: .continuous))
    }

    // MARK: - Rows

    private var scriptRow: some View {
        VStack(spacing: 10) {
            ScrollModePicker(selection: preferences.prompter.scrollMode) { viewModel.setScrollMode($0) }
            scriptControls
        }
    }

    private var scriptControls: some View {
        HStack {
            if preferences.prompter.scrollMode == .voice {
                VoiceIndicator(level: viewModel.voiceLevel, isListening: viewModel.isPlaying && viewModel.isVoiceActive)
            } else {
                SpeedStepper(
                    speedLabel: preferences.prompter.speedLabel,
                    onSlower: { viewModel.changeSpeed(by: -0.1) },
                    onFaster: { viewModel.changeSpeed(by: 0.1) }
                )
            }
            Spacer()
            Button { viewModel.rewind() } label: { Image(systemName: "arrow.up.to.line") }
                .buttonStyle(.cueIcon(.overlay))
                .accessibilityLabel(Text("Back to the top"))
            Spacer()
            Button { viewModel.togglePlay() } label: {
                Image(systemName: viewModel.isPlaying ? "pause.fill" : "play.fill")
            }
            .buttonStyle(.cueIcon(.overlay))
            .accessibilityLabel(Text(viewModel.isPlaying ? "Pause" : "Play"))
            .accessibilityIdentifier("prompter.playButton")
            Spacer()
            Button { viewModel.sheet = .display } label: {
                Text("Aa").font(.system(size: 17, weight: .semibold))
            }
            .buttonStyle(.cueIcon(.overlay))
            .accessibilityLabel(Text("Display settings"))
            .accessibilityIdentifier("prompter.displayButton")
        }
        .frame(height: 44)
    }

    private var freestyleRow: some View {
        HStack {
            VStack(alignment: .leading, spacing: 1) {
                Text("Freestyle").font(.subheadline.weight(.semibold))
                Text("No script — add one anytime")
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
        .frame(height: 44)
    }

    private var cameraRow: some View {
        HStack {
            Button { viewModel.openLastTake() } label: {
                Group {
                    if let take = viewModel.lastTake {
                        TakeThumbnail(take: take)
                    } else {
                        Palette.overlayFill
                    }
                }
                .frame(width: 44, height: 44)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(Color.white.opacity(0.7), lineWidth: 1.5))
            }
            .buttonStyle(.plain)
            .disabled(viewModel.lastTake == nil || viewModel.isRecording)
            .accessibilityLabel(Text("Last take"))
            Spacer()
            Button { viewModel.sheet = .camera } label: { Image(systemName: "slider.horizontal.3") }
                .buttonStyle(.cueIcon(.overlay))
                .disabled(viewModel.isRecording)
                .accessibilityLabel(Text("Camera settings"))
                .accessibilityIdentifier("prompter.cameraSettingsButton")
            Spacer()
            RecordButton(isRecording: viewModel.isRecording, isCountingDown: viewModel.countdown != nil) {
                Task { await viewModel.recordButtonTapped() }
            }
            Spacer()
            Button { viewModel.flipCamera() } label: { Image(systemName: "arrow.triangle.2.circlepath.camera") }
                .buttonStyle(.cueIcon(.overlay))
                .disabled(viewModel.isRecording)
                .accessibilityLabel(Text("Switch camera"))
            Spacer()
            countdownButton
        }
    }

    private var countdownButton: some View {
        let countdown = preferences.camera.countdown
        return Button { viewModel.cycleCountdown() } label: {
            VStack(spacing: 1) {
                Image(systemName: "timer").font(.system(size: 16, weight: .semibold))
                Text(countdown.shortLabel).font(.system(size: 9, weight: .bold))
            }
            .foregroundStyle(countdown == .off ? Color.white : Palette.acc)
            .frame(width: 44, height: 44)
            .background(countdown == .off ? Palette.overlayFill : Palette.acc.opacity(0.18), in: Circle())
        }
        .buttonStyle(.plain)
        .disabled(viewModel.isRecording)
        .accessibilityLabel(Text("Countdown"))
        .accessibilityValue(Text(countdown.label))
    }
}
