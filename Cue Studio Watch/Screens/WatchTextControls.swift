//
//  WatchTextControls.swift
//  Cue Studio Watch
//

import SwiftUI

/// The text's controls, in a rehearsal and on a take's second page: Back three lines, Read or Pause (yellow, never red),
/// and in manual reading the speed, by − and + or by the Digital Crown once its control is tapped. With Voice Following the
/// voice sets the pace. During a take, paused text says the camera goes on.
struct WatchTextControls: View {
    @Bindable var session: WatchSessionModel
    let isRecording: Bool

    var body: some View {
        let state = session.state
        let followsVoice = state?.followsVoice ?? false
        let isPlaying = state?.isPlaying ?? false
        if followsVoice {
            Label("Voice Following", systemImage: "waveform")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(WatchPalette.voice)
        } else {
            Text("Manual reading")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(WatchPalette.inkMuted)
        }
        HStack(alignment: .top, spacing: 14) {
            control(symbol: "gobackward", caption: "Back", size: 46, ground: WatchPalette.surface, mark: WatchPalette.ink) {
                session.send(.backward)
            }
            .accessibilityLabel(Text("Back 3 lines"))
            control(
                symbol: isPlaying ? "pause.fill" : "play.fill", caption: playCaption(isPlaying), size: 56,
                ground: WatchPalette.reading, mark: WatchPalette.onReading, captionColor: WatchPalette.reading
            ) {
                session.send(.togglePlay)
            }
            .accessibilityLabel(Text(playCaption(isPlaying)))
        }
        if followsVoice {
            Text("The speed follows your voice.")
                .font(.caption2)
                .foregroundStyle(WatchPalette.inkSoft)
                .multilineTextAlignment(.center)
        } else {
            speed
        }
        if isRecording, !isPlaying {
            Text("The camera keeps recording.")
                .font(.caption2)
                .foregroundStyle(WatchPalette.recordText)
                .multilineTextAlignment(.center)
        }
        if !isRecording {
            Button("End rehearsal") { session.send(.endRehearsal) }
                .buttonStyle(WatchButtonStyle())
        }
    }

    private func playCaption(_ isPlaying: Bool) -> LocalizedStringKey {
        switch (isRecording, isPlaying) {
        case (true, true): "Pause text"
        case (true, false): "Resume text"
        case (false, true): "Pause"
        case (false, false): "Read"
        }
    }

    /// − , the speed (tap: the crown turns it), +.
    private var speed: some View {
        HStack(spacing: 4) {
            stepButton("minus", label: "Slower") { session.send(.slower) }
            Button {
                session.crownTurnsSpeed.toggle()
            } label: {
                VStack(spacing: 0) {
                    Text(WatchSpeed.label(session.crownSpeed))
                        .font(.body.weight(.semibold).monospacedDigit())
                    Text(session.crownTurnsSpeed ? "crown" : "speed")
                        .font(.caption2)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .foregroundStyle(session.crownTurnsSpeed ? WatchPalette.reading : WatchPalette.inkSoft)
                }
                .frame(maxWidth: .infinity, minHeight: 44)
                .background {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(session.crownTurnsSpeed ? WatchPalette.reading : WatchPalette.line, lineWidth: session.crownTurnsSpeed ? 2 : 1)
                }
            }
            .buttonStyle(.plain)
            .foregroundStyle(WatchPalette.ink)
            .accessibilityLabel(
                session.crownTurnsSpeed
                    ? Text("Crown adjusting speed \(WatchSpeed.label(session.crownSpeed)). Tap to release.")
                    : Text("Speed \(WatchSpeed.label(session.crownSpeed)). Tap to use the crown.")
            )
            .focusable(session.crownTurnsSpeed)
            .digitalCrownRotation(
                $session.crownSpeed, from: WatchSpeed.range.lowerBound, through: WatchSpeed.range.upperBound, by: 0.1,
                sensitivity: .low, isContinuous: false, isHapticFeedbackEnabled: true
            )
            .onChange(of: session.crownSpeed) { _, _ in
                if session.crownTurnsSpeed { session.crownMoved() }
            }
            stepButton("plus", label: "Faster") { session.send(.faster) }
        }
    }

    private func stepButton(_ symbol: String, label: LocalizedStringKey, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.body.weight(.semibold))
                .frame(width: 40, height: 44)
                .background(WatchPalette.surface, in: Capsule())
        }
        .buttonStyle(.plain)
        .foregroundStyle(WatchPalette.ink)
        .accessibilityLabel(Text(label))
    }

    private func control(
        symbol: String, caption: LocalizedStringKey, size: CGFloat, ground: Color, mark: Color, captionColor: Color = WatchPalette.inkMuted,
        action: @escaping () -> Void
    ) -> some View {
        VStack(spacing: 2) {
            Button(action: action) {
                Image(systemName: symbol)
                    .font(.system(size: size * 0.38, weight: .bold))
                    .foregroundStyle(mark)
                    .frame(width: size, height: size)
                    .background(ground, in: Circle())
            }
            .buttonStyle(.plain)
            Text(caption)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(captionColor)
                .accessibilityHidden(true)
        }
    }
}
