//
//  PracticeBottomBar.swift
//  Cue Studio
//

import SwiftUI

/// The two ways on at the bottom of the practice (1.6): "Record my first video" (yellow, with a red dot; it takes a soft glow when the text
/// has been read) opens the real recorder with the same text, and "Explore Cue first" goes to Scripts. Without the microphone, a line above
/// them says Voice Following needs it and the way to Settings.
struct PracticeBottomBar: View {
    let viewModel: PrompterViewModel
    let onChoose: (PracticeOutcome) -> Void

    @Environment(\.openURL) private var openURL
    @Environment(\.scenePhase) private var scenePhase

    private var microphoneIsOff: Bool { viewModel.practiceVoice == .steady }

    var body: some View {
        VStack(spacing: 0) {
            if microphoneIsOff { microphoneNote.padding(.bottom, 10) }
            recordButton
            studioButton.padding(.top, 8)
        }
        .padding(.horizontal, 16)
        // Back from Settings, where it may have been turned on.
        .onChange(of: scenePhase) { _, phase in if phase == .active { viewModel.refreshPracticeMicrophone() } }
        .animation(.smooth(duration: 0.25), value: microphoneIsOff)
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
            .shadow(color: Palette.acc.opacity(viewModel.practiceStage == .done ? 0.45 : 0), radius: 15)
            .animation(.easeOut(duration: 0.6), value: viewModel.practiceStage == .done)
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
