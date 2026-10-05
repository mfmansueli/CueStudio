//
//  PracticeBars.swift
//  Cue Studio
//

import AVFAudio
import SwiftUI

/// How the practice run of the first flight ends.
enum PracticeOutcome {
    /// "Record it for real": the same screen, now recording-ready.
    case recordForReal
    /// "Not now — take me to my studio".
    case studio
}

/// Close, and "✦ PRACTICE · NOT RECORDING": the practice never records.
struct PracticeTopBar: View {
    let onClose: () -> Void

    var body: some View {
        HStack {
            Button(action: onClose) { Image(systemName: "xmark") }
                .buttonStyle(.cueIcon(.glass, diameter: 40))
                .accessibilityLabel(Text("Close"))
                .accessibilityIdentifier("prompter.closeButton")
            Spacer(minLength: 8)
            Text("✦ PRACTICE · NOT RECORDING")
                .font(CueStudioFont.hud)
                .tracking(1.2)
                .foregroundStyle(Palette.aiTextStrong)
                .padding(.horizontal, 14)
                .frame(height: 38)
                .glassNight(density: .solid)
                .accessibilityIdentifier("practice.chip")
        }
    }
}

/// The practice's toolbar, over a camera that covers the whole screen: so it sits on night glass, like the recorder's. Voice | Steady
/// (the real recorder's switch, with rewind and play), the speed or the voice line, and the two ways on as two real buttons:
/// record it for real, or go to the studio. Without the microphone Voice Following can't listen: its segment is off and the
/// panel says so, once, with the way to Settings.
struct PracticeBottomBar: View {
    let viewModel: PrompterViewModel
    let onChoose: (PracticeOutcome) -> Void

    @Environment(SessionSetupService.self) private var session
    @Environment(\.openURL) private var openURL
    @Environment(\.scenePhase) private var scenePhase
    @State private var microphoneIsOff = false

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 40, style: .continuous)
        VStack(spacing: 10) {
            modeRow
            detail
            recordButton
            studioButton
        }
        .padding(EdgeInsets(top: 12, leading: 12, bottom: 14, trailing: 12))
        .background(.ultraThinMaterial, in: shape)
        .glassNight(in: shape, density: .solid)
        .padding(.bottom, 8)
        .animation(.smooth(duration: 0.25), value: microphoneIsOff)
        .animation(.smooth(duration: 0.25), value: session.prompter.scrollMode)
        .onAppear(perform: readMicrophone)
        // Back from Settings, where it may have been turned on.
        .onChange(of: scenePhase) { _, phase in if phase == .active { readMicrophone() } }
    }

    // MARK: - Rows

    /// Voice | Steady, back to the top and play: the real recorder's own controls.
    private var modeRow: some View {
        HStack(spacing: 8) {
            ScrollModePicker(selection: session.prompter.scrollMode, isVoiceAvailable: !microphoneIsOff) { viewModel.setScrollMode($0) }
            Button { viewModel.rewind() } label: { Image(systemName: "arrow.up.to.line") }
                .buttonStyle(.cueIcon(.overlay))
                .accessibilityLabel(Text("Back to the top"))
                .accessibilityIdentifier("practice.rewind")
            Button { viewModel.togglePlay() } label: { Image(systemName: viewModel.isPlaying ? "pause.fill" : "play.fill") }
                .buttonStyle(.cueIcon(.overlay))
                .accessibilityLabel(Text(viewModel.isPlaying ? "Pause" : "Play"))
                .accessibilityIdentifier("practice.play")
        }
        .frame(height: Metrics.hitTarget)
    }

    /// What goes under the switch: the voice line, or the speed. Without the microphone, the way to turn it on comes first.
    @ViewBuilder
    private var detail: some View {
        if microphoneIsOff {
            microphoneNote
        }
        if session.prompter.scrollMode == .voice, !microphoneIsOff {
            VoiceIndicator(
                level: viewModel.voiceLevel, isListening: viewModel.isPlaying && viewModel.isVoiceActive,
                status: viewModel.voiceFollowStatus, speedLabel: session.prompter.speedLabel
            )
        } else {
            SpeedSlider(speed: session.prompter.speed, onChange: { viewModel.setSpeed($0) })
        }
    }

    private var microphoneNote: some View {
        HStack(spacing: 10) {
            Image(systemName: "mic.slash.fill")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Palette.warnText)
            Text("Voice Following needs the microphone.")
                .font(.caption)
                .foregroundStyle(Palette.ink2)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
            }
            .buttonStyle(.cueGlass(.compact, expands: false))
            .accessibilityIdentifier("practice.openSettings")
        }
        .padding(.horizontal, 10)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("practice.microphoneOff")
    }

    // MARK: - The two ways on

    private var recordButton: some View {
        Button { onChoose(.recordForReal) } label: {
            HStack(spacing: 10) {
                Circle().fill(Palette.warn).frame(width: 14, height: 14)
                Text("Record it for real").font(.system(size: 17, weight: .bold))
            }
            .foregroundStyle(Palette.accInk)
            .frame(maxWidth: .infinity, minHeight: 54)
            .background(Palette.acc, in: Capsule())
            .shineSweep(interval: 5)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("practice.recordForReal")
    }

    private var studioButton: some View {
        Button { onChoose(.studio) } label: {
            Text("Not now — take me to my studio")
        }
        .buttonStyle(.cueGlass(.medium))
        .accessibilityIdentifier("practice.notNow")
    }

    private func readMicrophone() {
        microphoneIsOff = AVAudioApplication.shared.recordPermission == .denied
    }
}
