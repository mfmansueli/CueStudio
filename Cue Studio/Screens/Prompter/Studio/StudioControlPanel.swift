//
//  StudioControlPanel.swift
//  Cue Studio
//

import SwiftUI

/// Studio's bar (v30): the prompter and nothing else, in the same night glass as Selfie's. Row 1 is the transport: Voice | Steady, back
/// three lines, play, forward three lines. Row 2 is the speed (Steady) or what Voice Following is doing. Row 3 is the quick
/// adjustments (`StudioAdjustBar`). No microphone line, no setup, no capture row: Studio doesn't record.
struct StudioControlPanel: View {
    let viewModel: PrompterViewModel
    let onHide: () -> Void

    @Environment(SessionSetupService.self) private var session

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 40, style: .continuous)
        VStack(spacing: 10) {
            hideHandle
            transport
            reading
            StudioAdjustBar(onMore: { viewModel.sheet = .display })
        }
        .padding(EdgeInsets(top: 4, leading: 12, bottom: 20, trailing: 12))
        .background(.ultraThinMaterial, in: shape)
        .glassNight(in: shape, density: .solid)
    }

    /// A small grabber that puts the bar away, so only the words are left on the screen.
    private var hideHandle: some View {
        Button(action: onHide) {
            Capsule()
                .fill(Palette.ink3)
                .frame(width: 36, height: 5)
                .frame(maxWidth: .infinity, minHeight: 24)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text("Hide controls"))
        .accessibilityIdentifier("studio.hideControls")
    }

    private var transport: some View {
        HStack(spacing: 8) {
            ScrollModePicker(selection: session.prompter.scrollMode) { viewModel.setScrollMode($0) }
            Button { viewModel.jump(lines: -3) } label: { Image(systemName: "chevron.backward.2") }
                .glassIconButton()
                .accessibilityLabel(Text("Back three lines"))
                .accessibilityIdentifier("prompter.backButton")
            Button { viewModel.togglePlay() } label: {
                Image(systemName: viewModel.isPlaying ? "pause.fill" : "play.fill")
            }
            .glassIconButton()
            .accessibilityLabel(Text(viewModel.isPlaying ? "Pause" : "Play"))
            .accessibilityIdentifier("prompter.playButton")
            Button { viewModel.jump(lines: 3) } label: { Image(systemName: "chevron.forward.2") }
                .glassIconButton()
                .accessibilityLabel(Text("Forward three lines"))
                .accessibilityIdentifier("prompter.forwardButton")
        }
        .frame(height: Metrics.hitTarget)
    }

    /// Steady: the speed slider. Voice: the live voice line and what recognition is doing.
    @ViewBuilder
    private var reading: some View {
        if session.prompter.scrollMode == .voice {
            VoiceIndicator(
                level: viewModel.voiceLevel, isListening: viewModel.isPlaying && viewModel.isVoiceActive,
                status: viewModel.voiceFollowStatus, speedLabel: session.prompter.speedLabel
            )
            Text(voiceStatus)
                .font(.footnote.monospacedDigit())
                .foregroundStyle(Palette.ink2)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .accessibilityIdentifier("prompter.voiceStatus")
        } else {
            SpeedSlider(speed: session.prompter.speed, onChange: { viewModel.setSpeed($0) })
        }
    }

    /// Following the words, or scrolling at the set speed while the creator talks. A model getting ready or downloading says so before play.
    private var voiceStatus: String {
        let status = viewModel.voiceFollowStatus
        switch status {
        case .preparing, .downloading:
            return status.detail(speedLabel: session.prompter.speedLabel)
        case .followingWords, .scrollsWhileTalking:
            guard viewModel.isPlaying else { return String(localized: "Tap play, then start reading") }
            return status.detail(speedLabel: session.prompter.speedLabel)
        }
    }
}
