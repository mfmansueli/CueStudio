//
//  AudioInputPill.swift
//  Cue Studio
//

import SwiftUI

/// Which microphone the take records from, as the first half of the toolbar's HUD line
/// ("● IPHONE MIC · 1080P 30 · 9:16 ›"), so the creator can check it before tapping record. The
/// dot is green while that input is connected. Tapping it opens Audio Input.
struct AudioInputPill: View {
    let isEnabled: Bool
    let action: () -> Void

    @Environment(AudioInputManager.self) private var audio
    @Environment(CameraManager.self) private var camera

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                ColorDot(color: dotColor, size: 6)
                Text(title)
                    .textCase(.uppercase)
                    .lineLimit(1)
            }
            .font(CueStudioFont.hud)
            .tracking(0.6)
            .foregroundStyle(Palette.ink)
            .frame(minHeight: Metrics.hitTarget)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .accessibilityLabel(Text("Audio Input"))
        .accessibilityValue(Text(title))
        .accessibilityHint(Text("Choose the microphone to record with"))
        .accessibilityIdentifier("prompter.audioInputButton")
        .task { audio.startObservingRoute() }
        .onDisappear { audio.stopObservingRoute() }
        // The camera sets up the audio session as it starts; read the route it chose.
        .onChange(of: camera.status) { audio.startObservingRoute() }
    }

    private var title: String {
        guard audio.isMicrophoneAllowed else { return String(localized: "Microphone off") }
        return audio.inputInUse?.name ?? String(localized: "Microphone")
    }

    private var dotColor: Color {
        if !audio.isMicrophoneAllowed { return Palette.warn }
        return audio.currentInput == nil ? Palette.ink3 : Palette.success
    }
}

#if DEBUG
#Preview {
    AudioInputPill(isEnabled: true) {}
        .padding()
        .background(Palette.bg)
        .previewEnvironment()
}
#endif
