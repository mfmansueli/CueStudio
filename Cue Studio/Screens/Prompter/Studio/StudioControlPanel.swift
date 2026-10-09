//
//  StudioControlPanel.swift
//  Cue Studio
//

import SwiftUI

/// Studio's bar (v30): the prompter and nothing else, in the same night glass and the same folding sheet (`ControlSheet`) as Selfie's. Always in
/// the sheet, at the bottom: the transport (Voice | Steady, back three lines, play, forward three lines). Folded into it, above: the quick
/// adjustments (`StudioAdjustBar`), the slider of the one chosen and the speed (Steady) or what Voice Following is doing. The chevron on top
/// brings them out and puts them back; they arrive from the bottom up, one after another (`SheetReveal`). No microphone line, no setup, no capture
/// row: Studio doesn't record.
struct StudioControlPanel: View {
    let viewModel: PrompterViewModel
    /// The speed and the quick adjustments are out of the sheet.
    @Binding var isOut: Bool

    @Environment(SessionSetupService.self) private var session

    /// The blocks' own heights, measured; until then, guesses. The slider of the chosen adjustment is measured on its own (what it adds), apart from
    /// what the screen reserves for the sheet (the chips and the speed), so choosing one never changes that.
    @State private var chipsHeight: CGFloat = 62
    @State private var speedHeight: CGFloat = 60
    @State private var adjustmentHeight: CGFloat = 80
    @State private var transportHeight: CGFloat = 80
    /// The quick adjustment chosen in the bar, the last one chosen (its slider is still there while it fades out) and how open its slider is, 0...1.
    @State private var selected: StudioAdjustment?
    @State private var lastSelected: StudioAdjustment = .size
    @State private var adjustmentOpen: CGFloat = 0
    /// The slider is in the view while it is open or closing, and leaves when it has closed: the system slider ignores a parent's
    /// `accessibilityHidden`, and VoiceOver would land on a slider nobody can see.
    @State private var showsSlider = false
    /// The sheet has already folded itself for a first play: it does so once; after that it stays as the creator leaves it.
    @State private var hasFoldedForPlay = false

    private static let motion: Animation = .smooth(duration: 0.55)

    /// What the sheet brings out without an adjustment chosen: the chips and the speed, with their room (8 above, 10 between and 10 under).
    private var travel: CGFloat { 8 + chipsHeight + 10 + speedHeight + 10 }

    var body: some View {
        ControlSheet(
            isOut: $isOut, isRecording: false,
            baseHeight: transportHeight, travel: travel, recordingHeight: transportHeight,
            extra: adjustmentOpen * adjustmentHeight
        ) { progress, _ in
            VStack(spacing: 0) {
                foldable(progress)
                    // Half way out they are neither for touching nor for VoiceOver.
                    .allowsHitTesting(progress > 0.92)
                    .accessibilityHidden(progress < 0.5)
                // Room above the buttons: folded, they are the top of what shows, and their glass reaches past their frames, which the sheet's edge
                // would cut.
                transport
                    .padding(.top, 10)
                    .padding(.bottom, 20)
                    .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { transportHeight = $0 }
            }
            .padding(.horizontal, 12)
        }
        .onChange(of: selected) { _, new in
            if let new {
                lastSelected = new
                showsSlider = true
            }
            withAnimation(Self.motion) {
                adjustmentOpen = new == nil ? 0 : 1
            } completion: {
                if selected == nil { showsSlider = false }
            }
        }
        // The first time the text starts (the countdown that leads to it counts), the speed and the adjustments fold away, so what is left is the
        // text and the transport. Only the first time: a creator who brings them back for the next play means to have them.
        .onChange(of: viewModel.isPlaying || viewModel.countdown != nil) { _, starting in
            guard starting, !hasFoldedForPlay else { return }
            hasFoldedForPlay = true
            isOut = false
        }
    }

    /// What the chevron brings out: the quick adjustments, the slider of the one chosen (opening between them and the speed while one is chosen,
    /// with a divider under it) and the speed (or the voice line), right above the transport. The speed stays; choosing an adjustment makes
    /// the sheet grow upward to make room, and the new slider arrives as it does.
    private func foldable(_ progress: CGFloat) -> some View {
        VStack(spacing: 0) {
            StudioAdjustBar(
                selected: $selected,
                progress: progress,
                onMore: { viewModel.sheet = .display },
                onRemote: { viewModel.openRemoteControl() },
                isRemoteConnected: viewModel.isRemoteConnected,
                remoteStatus: viewModel.remote.state.label
            )
            .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { chipsHeight = $0 }
            .padding(.top, 8)
            .padding(.bottom, 10)
            adjustmentSlider
            VStack(spacing: 10) {
                reading
            }
            .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { speedHeight = $0 }
            .padding(.bottom, 10)
            .sheetReveal(progress, from: 0.08, to: 0.6)
        }
    }

    /// The slider of the chosen adjustment and a divider under it. Its height opens from nothing to its own and it fades in as it does, and the same
    /// the other way; the sheet's growth (`ControlSheet`'s `extra`) is the same number, so the two move together.
    private var adjustmentSlider: some View {
        VStack(spacing: 10) {
            if showsSlider {
                StudioAdjustSlider(adjustment: lastSelected)
                    .id(lastSelected)
                    .transition(.opacity)
            }
            Rectangle()
                .fill(Palette.glassBorder)
                .frame(height: 1)
                .accessibilityHidden(true)
        }
        .padding(.bottom, 10)
        // Measured while the slider is there: without it the block is only the divider.
        .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { if showsSlider { adjustmentHeight = $0 } }
        .animation(Self.motion, value: lastSelected)
        .frame(height: adjustmentOpen * adjustmentHeight, alignment: .top)
        .clipped()
        .opacity(adjustmentOpen)
        .allowsHitTesting(selected != nil)
        .accessibilityHidden(selected == nil)
    }

    private var transport: some View {
        HStack(spacing: 8) {
            ScrollModePicker(selection: session.prompter.scrollMode) { viewModel.setScrollMode($0) }
            Button { viewModel.jump(lines: -3) } label: { Image(systemName: "chevron.backward.2") }
                .glassIconButton()
                .accessibilityLabel(Text("Back three lines"))
                .accessibilityIdentifier("prompter.backButton")
            Button { viewModel.togglePlay() } label: {
                Image(systemName: viewModel.isPlaying ? "pause.fill" : "play.fill")
            }
            .glassIconButton()
            .accessibilityLabel(Text(viewModel.isPlaying ? "Pause" : "Play"))
            .accessibilityIdentifier("prompter.playButton")
            Button { viewModel.jump(lines: 3) } label: { Image(systemName: "chevron.forward.2") }
                .glassIconButton()
                .accessibilityLabel(Text("Forward three lines"))
                .accessibilityIdentifier("prompter.forwardButton")
        }
        .frame(height: Metrics.hitTarget)
    }

    /// Steady: the speed slider. Voice: the live voice line and what recognition is doing.
    @ViewBuilder
    private var reading: some View {
        if session.prompter.scrollMode == .voice {
            VoiceIndicator(
                level: viewModel.voiceLevel, isListening: viewModel.isPlaying && viewModel.isVoiceActive,
                status: viewModel.voiceFollowStatus, speedLabel: session.prompter.speedLabel
            )
            Text(voiceStatus)
                .font(.footnote.monospacedDigit())
                .foregroundStyle(Palette.ink2)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .accessibilityIdentifier("prompter.voiceStatus")
        } else {
            SpeedSlider(speed: session.prompter.speed, onChange: { viewModel.setSpeed($0) })
        }
    }

    /// Following the words, or scrolling at the set speed while the creator talks. A model getting ready or downloading says so before play.
    private var voiceStatus: String {
        let status = viewModel.voiceFollowStatus
        switch status {
        case .preparing, .downloading:
            return status.detail(speedLabel: session.prompter.speedLabel)
        case .followingWords, .scrollsWhileTalking:
            guard viewModel.isPlaying else { return String(localized: "Tap play, then start reading") }
            return status.detail(speedLabel: session.prompter.speedLabel)
        }
    }
}
