//
//  PracticeVoiceStatus.swift
//  Cue Studio
//

import SwiftUI

/// The line under the practice's box (1.6): what moves the text right now, as it really is (`PracticeVoice`): getting ready to follow the
/// voice, following it or waiting for it, moving while the creator talks, or a steady scroll without the microphone. A small capsule of
/// glass; the waveform moves while the voice is heard (not with Reduce Motion).
struct PracticeVoiceStatus: View {
    let voice: PracticeVoice
    let isReading: Bool
    let isListening: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let text = voice.status(isReading: isReading, isListening: isListening)
        HStack(spacing: 6) {
            Image(systemName: voice.symbolName)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(voice == .steady ? Palette.warnText : Palette.accText)
                .symbolEffect(.variableColor.iterative, isActive: isListening && isReading && !reduceMotion)
                .contentTransition(.symbolEffect(.replace))
            Text(text)
                .font(.system(size: 12.5, weight: .semibold))
                .foregroundStyle(Palette.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .contentTransition(.opacity)
        }
        .padding(.horizontal, 12)
        .frame(height: 26)
        .glassEffect(.regular.tint(Palette.Flight.dim.opacity(0.5)), in: .capsule)
        .animation(reduceMotion ? nil : .easeOut(duration: 0.2), value: text)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Voice Following"))
        .accessibilityValue(Text(text))
        .accessibilityIdentifier("practice.voiceStatus")
    }
}
