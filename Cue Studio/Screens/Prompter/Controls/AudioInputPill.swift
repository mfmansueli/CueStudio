//
//  AudioInputPill.swift
//  Cue Studio
//

import SwiftUI

/// Which microphone the take records from, next to the capture controls, so the creator can
/// check it before tapping record. The dot is green while that input is connected. Tapping it opens
/// Audio Input.
struct AudioInputPill: View {
    let isEnabled: Bool
    let action: () -> Void

    @Environment(AudioInputManager.self) private var audio
    @Environment(CameraManager.self) private var camera

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: audio.isMicrophoneAllowed ? "mic.fill" : "mic.slash.fill")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(Palette.ink2)
                ColorDot(color: dotColor, size: 6)
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Palette.ink)
                    .lineLimit(1)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .frame(minHeight: 26)
            .background(Palette.overlayFill, in: Capsule())
            .frame(minHeight: 40)
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
