//
//  RecordingCompactBar.swift
//  Cue Studio
//

import SwiftUI

/// What the controls become while a take records: the mode chip with the speed (or the live
/// waveform), back to the top and pause, the stop button with the clock in yellow and
/// "TAKE 4 · TIKTOK SETUP", and a line that says how to bring the rest back (tap the screen).
struct RecordingCompactBar: View {
    let viewModel: PrompterViewModel

    @Environment(SessionSetupService.self) private var session
    @Environment(TakeLibraryService.self) private var takes

    var body: some View {
        VStack(spacing: 10) {
            topRow
            stopRow
            Text("Tap the screen for controls")
                .font(.caption)
                .foregroundStyle(Palette.ink2)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("prompter.compactBar")
    }

    // MARK: - Rows

    private var topRow: some View {
        HStack(spacing: 8) {
            modeChip
            if viewModel.hasScript {
                if isSteady {
                    CueSlider(
                        value: Binding(
                            get: { PrompterSettings.wordsPerMinute(forSpeed: session.prompter.speed).rounded() },
                            set: { viewModel.setSpeed(PrompterSettings.speed(forWordsPerMinute: $0)) }
                        ),
                        range: CueSliderSpec.speed.range, step: CueSliderSpec.speed.step, defaultValue: CueSliderSpec.speed.defaultValue,
                        style: .bare, label: String(localized: "Speed"),
                        valueText: String(localized: "\(Int(PrompterSettings.wordsPerMinute(forSpeed: session.prompter.speed).rounded())) wpm"),
                        accessibilityIdentifier: "prompter.speedSlider"
                    )
                    .padding(.horizontal, 6)
                } else {
                    Spacer(minLength: 0)
                }
                Button { viewModel.rewind() } label: { Image(systemName: "arrow.up.to.line") }
                    .buttonStyle(.cueIcon(.overlay))
                    .accessibilityLabel(Text("Back to the top"))
                Button { viewModel.togglePlay() } label: {
                    Image(systemName: viewModel.isPlaying ? "pause.fill" : "play.fill")
                }
                .buttonStyle(.cueIcon(.overlay))
                .accessibilityLabel(Text(viewModel.isPlaying ? "Pause" : "Play"))
                .accessibilityIdentifier("prompter.playButton")
            } else {
                Spacer(minLength: 0)
            }
        }
        .frame(height: Metrics.hitTarget)
    }

    private var stopRow: some View {
        HStack(spacing: 10) {
            Button { Task { await viewModel.recordButtonTapped() } } label: {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(Palette.record)
                    .frame(width: 24, height: 24)
                    .frame(width: 64, height: 64)
                    .overlay(Circle().strokeBorder(Color.white, lineWidth: 3))
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text("Stop recording"))
            .accessibilityIdentifier("prompter.recordButton")
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 7) {
                    Circle().fill(Palette.record).frame(width: 8, height: 8)
                    Text(DurationText.recording(viewModel.recordingSeconds))
                        .font(.system(size: 22, weight: .bold, design: .monospaced))
                        .tracking(1)
                        .foregroundStyle(Palette.accText)
                }
                Text(subtitle)
                    .font(.system(size: 10.5, weight: .bold, design: .monospaced))
                    .tracking(0.8)
                    .textCase(.uppercase)
                    .foregroundStyle(Palette.ink2)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("prompter.recordingClock")
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 4)
    }

    // MARK: - Pieces

    private var isSteady: Bool { session.prompter.scrollMode == .steady }

    /// "VOICE FOLLOWING" with the live waveform, or "STEADY 0.7×", or "FREESTYLE" with no script.
    private var modeChip: some View {
        let isVoice = viewModel.hasScript && !isSteady
        return HStack(spacing: 6) {
            if isVoice {
                bars
            } else if viewModel.hasScript {
                Image(systemName: "text.line.first.and.arrowtriangle.forward")
                    .font(.footnote.weight(.semibold))
            }
            Text(chipTitle)
                .font(.system(size: 11, weight: .heavy, design: .monospaced))
                .tracking(0.4)
                .textCase(.uppercase)
                .lineLimit(1)
        }
        .foregroundStyle(isVoice ? Palette.accText : Palette.ink)
        .padding(.leading, 10)
        .padding(.trailing, 12)
        .frame(height: Metrics.hitTarget)
        .background(isVoice ? Palette.accSoft : Palette.overlayFill, in: Capsule())
        .overlay(Capsule().strokeBorder(isVoice ? Palette.acc.opacity(0.45) : Palette.glassBorder, lineWidth: 1))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(chipTitle))
        .accessibilityIdentifier("prompter.modeChip")
    }

    private var chipTitle: String {
        guard viewModel.hasScript else { return String(localized: "Freestyle") }
        let mode = session.prompter.scrollMode
        return isSteady ? "\(mode.label) \(session.prompter.speedLabel)" : mode.label
    }

    private var bars: some View {
        let listening = viewModel.isPlaying && viewModel.isVoiceActive
        let weights = [0.55, 0.85, 1.0, 0.75, 0.6]
        return HStack(spacing: 2.5) {
            ForEach(0..<5, id: \.self) { index in
                Capsule()
                    .fill(Palette.acc)
                    .frame(width: 3, height: 18 * (listening ? max(0.25, min(1, viewModel.voiceLevel * weights[index] * 1.4)) : 0.3))
            }
        }
        .frame(height: 18)
        .accessibilityHidden(true)
    }

    /// "Take 4 · TikTok setup" (or "Freestyle · Take 4" without a script).
    private var subtitle: String {
        let number = String(localized: "Take \(takes.nextNumber(for: viewModel.scriptID))")
        if viewModel.hasScript {
            return number + " · " + viewModel.session.captureSource.label
        }
        return String(localized: "Freestyle") + " · " + number
    }
}
