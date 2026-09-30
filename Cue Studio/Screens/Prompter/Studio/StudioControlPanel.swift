//
//  StudioControlPanel.swift
//  Cue Studio
//

import SwiftUI

/// Speed slider (or Voice follow's status) and playback controls for Studio mode.
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
                speedRow
            }
            Rectangle()
                .fill(Color.white.opacity(0.1))
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
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 40, style: .continuous))
    }

    // MARK: - Rows

    private var speedRow: some View {
        HStack(spacing: 12) {
            Text("Speed")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Palette.ink2)
                // At least the column width; longer words ("Velocidade") push the slider over.
                .fixedSize()
                .frame(minWidth: 44, alignment: .leading)
            Slider(value: Binding(get: { session.prompter.speed }, set: { viewModel.setSpeed($0) }), in: PrompterSettings.speedRange, step: 0.1)
                .tint(Palette.acc)
                .accessibilityLabel(Text("Speed"))
                .accessibilityValue(Text(session.prompter.speedLabel))
            Text(session.prompter.speedLabel)
                .font(.body.weight(.semibold).monospacedDigit())
                .fixedSize()
                .frame(minWidth: 44, alignment: .trailing)
        }
        .frame(minHeight: 34)
    }

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
