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

/// "Read it out loud." and the two ways on: record it for real, or go to the studio. If the microphone was refused, the card
/// says so quietly: the text then scrolls on its own, and Settings is one tap away.
struct PracticeBottomBar: View {
    let onChoose: (PracticeOutcome) -> Void

    @Environment(\.openURL) private var openURL
    @Environment(\.scenePhase) private var scenePhase
    @State private var microphoneIsOff = false

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 14) {
                if microphoneIsOff {
                    Image(systemName: "mic.slash.fill")
                        .font(.system(size: 22, weight: .semibold)).foregroundStyle(Palette.warnText)
                        .frame(width: 26)
                } else {
                    CueIconView(.followsVoice, size: 26).foregroundStyle(Palette.acc)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(microphoneIsOff ? "Microphone off" : "Read it out loud.")
                        .font(.system(size: 17, weight: .semibold)).foregroundStyle(.white)
                    Text(microphoneIsOff
                        ? "The text scrolls on its own. Turn the microphone on in Settings to have it follow your voice."
                        : "Speed up, slow down, pause. The text follows you.")
                        .font(.system(size: 14)).foregroundStyle(Color.white.opacity(0.7))
                    if microphoneIsOff {
                        Button("Open Settings") {
                            if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                        }
                        .buttonStyle(.cueGlass(.compact, expands: false))
                        .padding(.top, 6)
                        .accessibilityIdentifier("practice.openSettings")
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(16)
            .glassNight(in: RoundedRectangle(cornerRadius: 22, style: .continuous), density: .solid)
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier(microphoneIsOff ? "practice.microphoneOff" : "practice.hint")
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
            Button { onChoose(.studio) } label: {
                Text("Not now — take me to my studio")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.8))
                    .frame(maxWidth: .infinity, minHeight: Metrics.hitTarget)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("practice.notNow")
        }
        .padding(.bottom, 8)
        .animation(.easeOut(duration: 0.25), value: microphoneIsOff)
        .onAppear(perform: readMicrophone)
        // Back from Settings, where it may have been turned on.
        .onChange(of: scenePhase) { _, phase in if phase == .active { readMicrophone() } }
    }

    private func readMicrophone() {
        microphoneIsOff = AVAudioApplication.shared.recordPermission == .denied
    }
}
