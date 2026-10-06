//
//  StudioModeView.swift
//  Cue Studio
//

import SwiftUI

/// Studio (v30): the prompter, only. The screen is the text on a dark background (mirrored if the glass needs it), with no camera and
/// no recording. It is for rehearsing the text, for setting where it sits for the eyes and how fast it goes, and for reading from while
/// another camera films. The bar below has the transport, the speed and a few quick adjustments; the grabber puts it away, and a tap
/// on the words plays or pauses.
struct StudioModeView: View {
    let viewModel: PrompterViewModel
    let onClose: () -> Void

    @Environment(SessionSetupService.self) private var session
    @Environment(AudioInputManager.self) private var audio
    @State private var hidesBar = false

    var body: some View {
        let settings = session.prompter
        ZStack {
            settings.studioBackground.color.ignoresSafeArea()
            VStack(spacing: 0) {
                VStack(spacing: 6) {
                    ProgressLine(viewModel: viewModel)
                    StudioTimeLine(viewModel: viewModel)
                }
                .padding(.horizontal, 20)
                .padding(.top, 10)
                // The text uses the room the bar leaves; the reading line is a fraction of it.
                GeometryReader { proxy in
                    PrompterTextView(
                        viewModel: viewModel,
                        settings: settings,
                        viewportHeight: proxy.size.height,
                        onTap: { viewModel.togglePlay() }
                    )
                    .overlay { PrompterTextOverlays(viewModel: viewModel) }
                    .frame(height: proxy.size.height, alignment: .top)
                }
                .padding(.top, 5)
                if !audio.isMicrophoneAllowed, settings.scrollMode == .voice, !hidesBar {
                    MicrophoneNeededCard()
                        .padding(.horizontal, 18)
                        .padding(.bottom, 12)
                }
                if hidesBar {
                    showBarButton
                } else {
                    // While it counts down the bar steps aside (it keeps its room, so the text doesn't move) and the overlay's hint reads clearly.
                    StudioControlPanel(viewModel: viewModel, onHide: { hidesBar = true })
                        .padding(.horizontal, 10)
                        .opacity(viewModel.countdown == nil ? 1 : 0)
                        .allowsHitTesting(viewModel.countdown == nil)
                        .animation(.easeOut(duration: 0.2), value: viewModel.countdown == nil)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .animation(.smooth(duration: 0.3), value: hidesBar)
            if let countdown = viewModel.countdown {
                CountdownOverlay(
                    value: countdown, total: session.camera.countdown.rawValue,
                    hint: settings.scrollMode == .voice && viewModel.hasScript ? String(localized: "Just talk. The text follows your voice.") : nil,
                    onCancel: { viewModel.cancelCountdown() }
                )
                .transition(.opacity)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackgroundVisibility(.hidden, for: .navigationBar)
        .toolbar { topBar }
    }

    /// The navigation bar, the system's: close at the start, Selfie | Studio in the middle and, at the end, the script's platform ("● TikTok",
    /// opens Create for, which sets the ideal length shown above the text) and Remote.
    @ToolbarContentBuilder
    private var topBar: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            Button(role: .close, action: onClose)
                .accessibilityIdentifier("prompter.closeButton")
        }
        ToolbarItem(placement: .principal) {
            ModeSwitcher(mode: .studio) { mode in
                Task { await viewModel.switchMode(to: mode) }
            }
        }
        if let script = viewModel.script {
            ToolbarItem(placement: .topBarTrailing) {
                Button { viewModel.platformChipTapped() } label: {
                    HStack(spacing: 6) {
                        PlatformDot(color: script.platform.tint)
                        Text(script.platform.label).font(.footnote.weight(.semibold))
                    }
                    .foregroundStyle(Palette.ink)
                }
                .accessibilityLabel(Text("Create for"))
                .accessibilityValue(Text(script.platform.label))
                .accessibilityIdentifier("prompter.platformButton")
            }
            ToolbarSpacer(.fixed, placement: .topBarTrailing)
        }
        ToolbarItem(placement: .topBarTrailing) {
            Button { viewModel.openRemoteControl() } label: {
                Image(systemName: "iphone.radiowaves.left.and.right")
                    .foregroundStyle(viewModel.isRemoteConnected ? Palette.accText : Palette.ink)
            }
            .accessibilityLabel(Text("Remote Control"))
            .accessibilityValue(Text(viewModel.remote.state.label))
            .accessibilityIdentifier("prompter.remoteButton")
        }
    }

    /// With the bar put away: one small button to bring it back.
    private var showBarButton: some View {
        Button { hidesBar = false } label: { Image(systemName: "chevron.up") }
            .buttonStyle(.cueIcon(.glass, diameter: 44))
            .padding(.bottom, 14)
            .accessibilityLabel(Text("Show controls"))
            .accessibilityIdentifier("studio.showControls")
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
