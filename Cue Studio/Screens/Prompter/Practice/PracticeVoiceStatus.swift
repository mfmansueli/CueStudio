//
//  PracticeVoiceStatus.swift
//  Cue Studio
//

import SwiftUI

/// The line under the practice's box (1.6): what moves the text right now, as it really is (`PracticeVoice`): getting ready to follow the
/// voice, following it or waiting for it, moving while the creator talks, or a steady scroll without the microphone. A capsule of glass, 44 pt
/// tall, so the creator sees at a glance whether Cue hears them: when it listens, a waveform (`PracticeVoiceWave`) follows the microphone and
/// the capsule's rim glows yellow with the voice; while it waits, a slow ripple runs across the bars.
struct PracticeVoiceStatus: View {
    let voice: PracticeVoice
    let isReading: Bool
    let isListening: Bool
    /// 0...1, the microphone's level.
    let level: Double

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var listens: Bool { voice == .following || voice == .scrollsWhileTalking }
    private var glow: Double { listens && isListening ? min(1, 0.35 + level) : 0 }

    var body: some View {
        let text = voice.status(isReading: isReading, isListening: isListening)
        HStack(spacing: 10) {
            if listens {
                PracticeVoiceWave(level: level, isHearing: isListening)
            } else {
                Image(systemName: voice.symbolName)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(voice == .steady ? Palette.warnText : Palette.accText)
                    .symbolEffect(.pulse, isActive: voice != .steady && !reduceMotion)
                    .frame(width: 22)
            }
            Text(text)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Palette.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .contentTransition(.opacity)
        }
        .padding(.horizontal, 16)
        .frame(height: 44)
        .glassEffect(.regular.tint(Palette.Flight.dim.opacity(0.5)), in: .capsule)
        .overlay(Capsule().strokeBorder(Palette.acc.opacity(0.6 * glow), lineWidth: 1.2))
        .shadow(color: Palette.acc.opacity(0.35 * glow), radius: 14)
        .animation(reduceMotion ? nil : .easeOut(duration: 0.2), value: text)
        .animation(reduceMotion ? nil : .easeOut(duration: 0.15), value: glow)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Voice Following"))
        .accessibilityValue(Text(text))
        .accessibilityIdentifier("practice.voiceStatus")
    }
}
