//
//  SelfieControlSheet.swift
//  Cue Studio
//

import SwiftUI

/// Selfie's controls in one sheet. Folded, it is the chevron and what it takes to record (the microphone and setup line and the
/// capture row), as in the capture card of C; out, the reading controls too (mode, playback, speed), above those. Pulling the chevron up or
/// tapping it brings them out, and pulling it down or tapping it again folds them. They arrive one after another from the bottom up
/// (`SheetReveal`): the speed first, then the mode switch and the playback buttons one after another. The capture controls never move.
///
/// **Recording.** When a take starts the sheet gathers into one row, and the same record button goes through it: the reading controls fold
/// away, the microphone and setup line, the chevron and the side buttons fade, the record button turns into the stop button as it flies to
/// the start of the row, and the mode's symbol, the waveform (following the voice), the hint and back to the top and play arrive beside it; the clock and
/// the take's name are in the navigation bar. When the creator taps the screen or the card for the
/// controls, or the take ends, it all goes back the way it came.
struct SelfieControlSheet: View {
    let parts: SelfieControlParts
    @Binding var isOut: Bool

    /// The blocks' own heights, measured; until then, guesses.
    @State private var readingHeight: CGFloat = 130
    @State private var captureHeight: CGFloat = 140
    /// The capture row with its room (what is left of the sheet while recording) and its width, which the record button crosses.
    @State private var rowRegionHeight: CGFloat = 96
    @State private var rowWidth: CGFloat = 340

    private static let recordSize: CGFloat = 78
    /// Room above the capture row that the recording row keeps once the chevron is gone, so the stop button does not touch the sheet's top edge:
    /// with the row's own 2 pt it matches the 16 pt under it. What it uncovers is where the microphone and setup line was, faded out by then.
    private static let recordingTopRoom: CGFloat = 14

    var body: some View {
        ControlSheet(
            isOut: $isOut, isRecording: parts.viewModel.showsCompactBar,
            baseHeight: captureHeight, travel: readingHeight, recordingHeight: rowRegionHeight + Self.recordingTopRoom,
            // While a take records the whole card is "tap the screen for controls": a tap anywhere on it that is not a button (stop, back to the
            // top, play have their own) brings the controls back for a few seconds, as a tap on the picture does.
            onRecordingTap: { parts.viewModel.bar.expand() },
            content: { progress, recording in
            VStack(spacing: 0) {
                reading(progress)
                    .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { readingHeight = $0 }
                    // Half way out they are neither for touching nor for VoiceOver.
                    .allowsHitTesting(progress > 0.92)
                    .accessibilityHidden(progress < 0.5)
                capture(recording)
                    .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { captureHeight = $0 }
            }
            .padding(.horizontal, 12)
            }
        )
    }

    // MARK: - Reading

    /// What the chevron brings out: the mode switch and the playback buttons, then the speed (or what Voice Following is doing). The room above
    /// is for the buttons' own glass, which reaches past their frames and would be cut by the sheet's edge.
    private func reading(_ progress: CGFloat) -> some View {
        VStack(spacing: 10) {
            if parts.viewModel.hasScript {
                HStack(spacing: 8) {
                    parts.modePicker.sheetReveal(progress, from: 0.55, to: 0.95)
                    parts.rewindButton.sheetReveal(progress, from: 0.60, to: 0.97)
                    parts.playButton.sheetReveal(progress, from: 0.66, to: 0.99)
                    parts.displayButton.sheetReveal(progress, from: 0.72, to: 1.0)
                }
                .frame(height: Metrics.hitTarget)
                parts.speedBlock.sheetReveal(progress, from: 0.08, to: 0.6)
            } else {
                parts.freestyleRow.sheetReveal(progress, from: 0.1, to: 0.9)
            }
        }
        .padding(.top, 10)
        .padding(.bottom, 10)
    }

    // MARK: - Capture and recording

    /// What is always there: the microphone and setup line, then the capture row, which becomes the recording row.
    private func capture(_ recording: CGFloat) -> some View {
        VStack(spacing: 10) {
            parts.hudLine
                .opacity(1 - SheetReveal.smoothstep(recording, from: 0, to: 0.4))
                .allowsHitTesting(recording < 0.1)
            row(recording)
                .padding(.top, 2)
                .padding(.bottom, 16)
                .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { rowRegionHeight = $0 }
        }
    }

    /// The capture row and, over it, the recording row. The record button is one and the same in both: it moves from the middle of the row to
    /// its start and turns into the stop button on the way (`RecordButton` does that part), while the other four buttons give way and the
    /// recording row's pieces come in.
    private func row(_ recording: CGFloat) -> some View {
        let sides = 1 - SheetReveal.smoothstep(recording, from: 0, to: 0.4)
        let fly = SheetReveal.smoothstep(recording, from: 0.1, to: 0.8)
        let text = SheetReveal.smoothstep(recording, from: 0.5, to: 1.0)
        let tools = SheetReveal.smoothstep(recording, from: 0.6, to: 1.0)
        return ZStack {
            HStack {
                parts.lastTakeButton.opacity(sides).scaleEffect(0.8 + 0.2 * sides).allowsHitTesting(recording < 0.1)
                Spacer()
                parts.cameraSettingsButton.opacity(sides).scaleEffect(0.8 + 0.2 * sides).allowsHitTesting(recording < 0.1)
                Spacer()
                parts.recordButton.offset(x: -fly * (rowWidth / 2 - Self.recordSize / 2))
                Spacer()
                parts.flipButton.opacity(sides).scaleEffect(0.8 + 0.2 * sides).allowsHitTesting(recording < 0.1)
                Spacer()
                parts.moreMenu.opacity(sides).scaleEffect(0.8 + 0.2 * sides).allowsHitTesting(recording < 0.1)
            }
            HStack(spacing: 10) {
                // Where the record button lands.
                Color.clear.frame(width: Self.recordSize, height: Self.recordSize)
                recordingText
                    .opacity(text)
                    .offset(x: (1 - text) * -14)
                Spacer(minLength: 0)
                HStack(spacing: 8) {
                    parts.rewindButton
                    parts.playButton
                }
                .opacity(tools)
                .scaleEffect(0.85 + 0.15 * tools)
                .allowsHitTesting(recording > 0.9)
            }
            .accessibilityHidden(recording < 0.5)
        }
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { rowWidth = $0 }
        .padding(.horizontal, 6)
    }

    /// What the recording row says beside the stop button: the symbol of the mode the take is read in (Voice or Steady) and, following the voice,
    /// the waveform that answers it, then how to bring the controls back. The clock and the take's name are in the navigation bar
    /// (`RecordingBadge`, `RecordingTakeTitle`).
    private var recordingText: some View {
        let viewModel = parts.viewModel
        let mode = parts.session.prompter.scrollMode
        let followsVoice = viewModel.hasScript && mode == .voice
        return VStack(alignment: .leading, spacing: 8) {
            if viewModel.hasScript {
                HStack(spacing: 10) {
                    Image(systemName: mode.symbolName)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(followsVoice ? Palette.accText : Palette.ink)
                        .frame(width: 36, height: 36)
                        .background(Palette.overlayFill, in: Circle())
                        .accessibilityLabel(Text(mode.label))
                    if followsVoice {
                        VoiceWaveform(level: viewModel.voiceLevel, isListening: viewModel.isPlaying && viewModel.isVoiceActive, height: 24, barWidth: 4)
                    }
                }
            }
            Text("Tap the screen for controls")
                .font(.footnote)
                .foregroundStyle(Palette.ink2)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
    }
}
