//
//  StudioControlPanel.swift
//  Cue Studio
//

import SwiftUI

/// Speed slider (or Voice follow's status) and playback controls for Studio mode, in the same night
/// glass and with the same switch and slider as the Selfie toolbar. Studio doesn't record: a
/// second device films, so there is no capture row, and the jump buttons stay.
struct StudioControlPanel: View {
    let viewModel: PrompterViewModel

    @Environment(SessionSetupService.self) private var session

    var body: some View {
        VStack(spacing: 0) {
            ScrollModePicker(selection: session.prompter.scrollMode) { viewModel.setScrollMode($0) }
                .padding(.bottom, 12)
            if session.prompter.scrollMode == .voice {
                voiceRow
            } else {
                SpeedSlider(
                    speed: session.prompter.speed,
                    speedLabel: session.prompter.speedLabel,
                    onChange: { viewModel.setSpeed($0) }
                )
            }
            Rectangle()
                .fill(Palette.glassBorder)
                .frame(height: 0.5)
                .padding(.vertical, 12)
            HStack {
                Button { viewModel.rewind() } label: { Image(systemName: "arrow.up.to.line") }
                    .buttonStyle(.cueIcon(.overlay, diameter: 48))
                    .accessibilityLabel(Text("Back to the top"))
                Spacer()
                Button { viewModel.jump(lines: -3) } label: { Image(systemName: "chevron.backward.2") }
                    .buttonStyle(.cueIcon(.overlay, diameter: 48))
                    .accessibilityLabel(Text("Back three lines"))
                    .accessibilityIdentifier("prompter.backButton")
                Spacer()
                Button { viewModel.togglePlay() } label: {
                    Image(systemName: viewModel.isPlaying ? "pause.fill" : "play.fill")
                }
                .buttonStyle(.cueIcon(.accent, diameter: 72))
                .accessibilityLabel(Text(viewModel.isPlaying ? "Pause" : "Play"))
                .accessibilityIdentifier("prompter.playButton")
                Spacer()
                Button { viewModel.jump(lines: 3) } label: { Image(systemName: "chevron.forward.2") }
                    .buttonStyle(.cueIcon(.overlay, diameter: 48))
                    .accessibilityLabel(Text("Forward three lines"))
                    .accessibilityIdentifier("prompter.forwardButton")
                Spacer()
                Button { viewModel.sheet = .display } label: {
                    Text("Aa").font(.system(size: 18, weight: .semibold))
                }
                .buttonStyle(.cueIcon(.overlay, diameter: 48))
                .accessibilityLabel(Text("Display settings"))
                .accessibilityIdentifier("prompter.displayButton")
            }
        }
        .padding(EdgeInsets(top: 14, leading: 16, bottom: 14, trailing: 16))
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 40, style: .continuous))
        .glassNight(in: RoundedRectangle(cornerRadius: 40, style: .continuous), density: .solid)
    }

    // MARK: - Rows

    /// Following the words, or, without word-by-word recognition here (yet), scrolling at the set
    /// speed while the creator talks. A model getting ready or downloading says so before play.
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

    /// Following the reading, speed doesn't apply: the text moves at the creator's pace.
    private var voiceRow: some View {
        HStack(spacing: 12) {
            VoiceIndicator(
                level: viewModel.voiceLevel, isListening: viewModel.isPlaying && viewModel.isVoiceActive,
                status: viewModel.voiceFollowStatus, speedLabel: session.prompter.speedLabel, fillsWidth: true
            )
            Spacer(minLength: 0)
            Text(voiceStatus)
                .font(.footnote.monospacedDigit())
                .foregroundStyle(Palette.ink2)
                .lineLimit(3)
                .multilineTextAlignment(.trailing)
                .accessibilityIdentifier("prompter.voiceStatus")
        }
        .frame(minHeight: 34)
    }
}
