//
//  StudioModeView.swift
//  Cue Studio
//

import SwiftUI

/// Studio (v29 · 5.3): the prompter for rigs and beam-splitter glass. The screen is the text on a dark background (mirrored if the
/// glass needs it); the rear camera records through the glass, and a thumbnail of it sits in the corner without covering the
/// words. The bar is Selfie's: the mode switch, play and the speed, the microphone and setup line and the capture
/// row, and while a take records it becomes the compact one (a tap on the screen brings the whole bar back for 4 s).
struct StudioModeView: View {
    let viewModel: PrompterViewModel
    let onClose: () -> Void

    @Environment(SessionSetupService.self) private var session
    @Environment(AudioInputManager.self) private var audio

    var body: some View {
        let settings = session.prompter
        ZStack {
            settings.studioBackground.color.ignoresSafeArea()
            VStack(spacing: 0) {
                topBar
                    .padding(.horizontal, 14)
                ProgressLine(viewModel: viewModel)
                    .padding(.horizontal, 20)
                    .padding(.top, 10)
                GeometryReader { proxy in
                    // While a take records the box is a little narrower and shorter, and the thumbnail's margin stays.
                    PrompterTextView(
                        viewModel: viewModel,
                        settings: settings,
                        viewportHeight: proxy.size.height * (viewModel.isRecording ? ReadingLayout.recordingHeightFactor : 1),
                        onTap: { viewModel.togglePlay() }
                    )
                    .overlay { PrompterTextOverlays(viewModel: viewModel) }
                    .padding(.trailing, StudioCameraThumbnail.textMargin)
                    .padding(.leading, viewModel.isRecording ? ReadingLayout.recordingInset : 0)
                    .frame(height: proxy.size.height * (viewModel.isRecording ? ReadingLayout.recordingHeightFactor : 1), alignment: .top)
                }
                .padding(.top, 5)
                if !audio.isMicrophoneAllowed, !viewModel.isRecording {
                    MicrophoneNeededCard()
                        .padding(.horizontal, 18)
                        .padding(.bottom, 12)
                }
                SelfieControlPanel(viewModel: viewModel, isStudio: true)
                    .padding(.horizontal, 10)
            }
            .overlay(alignment: .topTrailing) {
                StudioCameraThumbnail(isRecording: viewModel.isRecording)
                    .padding(.trailing, 14)
                    .padding(.top, 62)
            }
            if viewModel.showsCompactBar {
                // Anywhere on the picture brings the whole bar back for a few seconds.
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture { viewModel.bar.expand() }
                    .accessibilityElement()
                    .accessibilityLabel(Text("Tap the screen for controls"))
                    .accessibilityAddTraits(.isButton)
                    .accessibilityIdentifier("prompter.showControlsArea")
                    .padding(.bottom, 150)
            }
            if let countdown = viewModel.countdown {
                CountdownOverlay(
                    value: countdown, total: session.camera.countdown.rawValue,
                    hint: session.prompter.scrollMode == .voice && viewModel.hasScript ? String(localized: "Just talk. The text follows your voice.") : nil,
                    onCancel: { Task { await viewModel.recordButtonTapped() } }
                )
                .transition(.opacity)
            }
        }
    }

    /// Close, the mode switch, Remote and mirror; while recording the REC pill takes the start.
    private var topBar: some View {
        let settings = session.prompter
        return HStack {
            if viewModel.isRecording {
                RecordingBadge(seconds: viewModel.recordingSeconds, monetizationChip: viewModel.monetizationChip)
                Spacer(minLength: 8)
            } else {
                Button(action: onClose) { Image(systemName: "xmark") }
                    .buttonStyle(.cueIcon(.glass, diameter: 40))
                    .accessibilityLabel(Text("Close"))
                    .accessibilityIdentifier("prompter.closeButton")
                Spacer()
                ModeSwitcher(mode: .studio) { mode in
                    Task { await viewModel.switchMode(to: mode) }
                }
                Spacer()
            }
            Button { viewModel.openRemoteControl() } label: {
                Image(systemName: "iphone.radiowaves.left.and.right")
            }
            .buttonStyle(.cueIcon(viewModel.isRemoteConnected ? .accent : .glass, diameter: 40))
            .accessibilityLabel(Text("Remote Control"))
            .accessibilityValue(Text(viewModel.remote.state.label))
            .accessibilityIdentifier("prompter.remoteButton")
            Button {
                session.prompter.isMirrored.toggle()
            } label: {
                Image(systemName: "arrow.left.and.right.righttriangle.left.righttriangle.right")
            }
            .buttonStyle(.cueIcon(settings.isMirrored ? .accent : .glass, diameter: 40))
            .accessibilityLabel(Text("Mirror text"))
            .accessibilityValue(Text(settings.isMirrored ? "On" : "Off"))
        }
    }

    /// Reads the scroll progress on its own so only this bar redraws while scrolling.
    private struct ProgressLine: View {
        let viewModel: PrompterViewModel

        var body: some View {
            UsageMeter(fraction: viewModel.engine.progress, color: Palette.acc, height: 3, animated: false)
                .accessibilityHidden(true)
        }
    }
}

#if DEBUG
#Preview {
    let viewModel = PrompterViewModel.preview(scriptID: SampleScripts.weeklyQA.id, mode: .studio)
    StudioModeView(viewModel: viewModel, onClose: {})
        .environment(viewModel.session)
        .previewEnvironment()
}
#endif
