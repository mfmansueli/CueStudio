//
//  PracticeBottomBar.swift
//  Cue Studio
//

import SwiftUI

/// The ways on at the bottom of the practice (1.6): "Explore Cue first" is always there, the way out, and goes to Scripts; "Record my first
/// video" (yellow, with a red dot and a soft glow) rises above it once play has been tapped (the owner's call: the practice comes first),
/// and opens the real recorder with the same text. Without the microphone, a line above them says Voice Following needs it and the
/// way to Settings.
struct PracticeBottomBar: View {
    let viewModel: PrompterViewModel
    let onChoose: (PracticeOutcome) -> Void

    @Environment(\.openURL) private var openURL
    @Environment(\.scenePhase) private var scenePhase

    private var microphoneIsOff: Bool { viewModel.practiceVoice == .steady }
    private var hasStarted: Bool { viewModel.practiceStage != .idle }

    var body: some View {
        VStack(spacing: 0) {
            if microphoneIsOff { microphoneNote.padding(.bottom, 10) }
            if hasStarted {
                recordButton
                    .padding(.bottom, 8)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
            studioButton
        }
        .padding(.horizontal, 16)
        // Back from Settings, where it may have been turned on.
        .onChange(of: scenePhase) { _, phase in if phase == .active { viewModel.refreshPracticeMicrophone() } }
        .animation(.smooth(duration: 0.25), value: microphoneIsOff)
        .animation(.smooth(duration: 0.5), value: hasStarted)
    }

    private var recordButton: some View {
        Button { onChoose(.recordForReal) } label: {
            HStack(spacing: 10) {
                Circle().fill(Palette.record).frame(width: 14, height: 14)
                Text("Record my first video").font(.system(size: 17, weight: .bold))
            }
            .foregroundStyle(Palette.accInk)
            .frame(maxWidth: .infinity, minHeight: 58)
            .background(Palette.acc, in: Capsule())
            .shineSweep(interval: 5)
            .shadow(color: Palette.acc.opacity(0.45), radius: 15)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("practice.recordForReal")
    }

    private var studioButton: some View {
        Button { onChoose(.studio) } label: {
            Text("Explore Cue first")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Palette.Flight.quietInk)
                .frame(maxWidth: .infinity, minHeight: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("practice.notNow")
    }

    private var microphoneNote: some View {
        HStack(spacing: 10) {
            Image(systemName: "mic.slash.fill")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Palette.warnText)
            Text("Turn on the microphone so the text can follow your voice.")
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
}
