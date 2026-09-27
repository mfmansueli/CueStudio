//
//  StudioControlPanel.swift
//  Cue Studio
//

import SwiftUI

/// Speed slider (or Voice follow's status) and playback controls for Studio mode.
struct StudioControlPanel: View {
    let viewModel: PrompterViewModel

    @Environment(PreferencesService.self) private var preferences

    var body: some View {
        VStack(spacing: 0) {
            if preferences.prompter.scrollMode == .voice && viewModel.followsSpeech {
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
        @Bindable var preferences = preferences
        return HStack(spacing: 12) {
            Text("Speed")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Palette.ink2)
                .frame(width: 44, alignment: .leading)
            Slider(value: $preferences.prompter.speed, in: PrompterSettings.speedRange, step: 0.1)
                .tint(Palette.acc)
                .accessibilityLabel(Text("Speed"))
                .accessibilityValue(Text(preferences.prompter.speedLabel))
            Text(preferences.prompter.speedLabel)
                .font(.body.weight(.semibold).monospacedDigit())
                .frame(width: 44, alignment: .trailing)
        }
        .frame(minHeight: 34)
    }

    /// Following the reading, speed doesn't apply: the text moves at the creator's pace.
    private var voiceRow: some View {
        HStack(spacing: 12) {
            VoiceIndicator(level: viewModel.voiceLevel, isListening: viewModel.isPlaying && viewModel.isVoiceActive)
            Text(viewModel.isPlaying ? "Following your reading" : "Tap play, then start reading")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Palette.ink2)
                .lineLimit(2)
            Spacer(minLength: 0)
        }
        .frame(minHeight: 34)
        .accessibilityIdentifier("prompter.voiceStatus")
    }
}
