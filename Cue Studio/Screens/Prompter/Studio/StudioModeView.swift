//
//  StudioModeView.swift
//  Cue Studio
//

import SwiftUI

/// Studio (v30): the prompter, only. The screen is the text on a dark background (mirrored if the glass needs it), with no camera and
/// no recording. It is for rehearsing the text, for setting where it sits for the eyes and how fast it goes, and for reading from while
/// another camera films. The bar below has the transport, the speed and a few quick adjustments; its chevron folds the speed and the
/// adjustments into it, leaving the transport, and a tap on the words plays or pauses.
struct StudioModeView: View {
    let viewModel: PrompterViewModel
    let onClose: () -> Void

    @Environment(SessionSetupService.self) private var session
    @Environment(AudioInputManager.self) private var audio
    /// The speed and the quick adjustments are out of the bar's sheet (the transport is always in it).
    @State private var controlsOut = true

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
                        // The text starts at the margin; the line goes 16 pt past it, as in Selfie.
                        guideInset: ReadingLayout.lineInset(textLeading: settings.margin),
                        onTap: { viewModel.togglePlay() }
                    )
                    .overlay { PrompterTextOverlays(viewModel: viewModel) }
                    .frame(height: proxy.size.height, alignment: .top)
                }
                // Where the text is on screen: Aa stops under its reading line.
                .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { viewModel.studioTextFrame = $0 }
                .padding(.top, 5)
                // Voice Following needs the microphone: asked for it, or fallen back to Steady without it.
                if !audio.isMicrophoneAllowed, settings.scrollMode == .voice || viewModel.sessionChoseScrollMode {
                    MicrophoneNeededCard()
                        .padding(.horizontal, 18)
                        .padding(.bottom, 12)
                }
                // While it counts down the bar steps aside (it keeps its room, so the text doesn't move) and the overlay's hint reads clearly.
                StudioControlPanel(viewModel: viewModel, isOut: $controlsOut)
                    .padding(.horizontal, 10)
                    .opacity(viewModel.countdown == nil ? 1 : 0)
                    .allowsHitTesting(viewModel.countdown == nil)
                    // VoiceOver loses it too, as touch does. Left in the accessibility tree while invisible, it came back stale: "Play" while
                    // the text played.
                    .accessibilityHidden(viewModel.countdown != nil)
                    .animation(.easeOut(duration: 0.2), value: viewModel.countdown == nil)
            }
            // The panel ends as low as Scripts' tab bar, inside the Home Indicator's strip; the text gets the room it leaves.
            .floatingBottomBarPlacement()
            if let countdown = viewModel.countdown {
                CountdownOverlay(value: countdown, onCancel: { viewModel.cancelCountdown() })
                .transition(.opacity)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackgroundVisibility(.hidden, for: .navigationBar)
        .toolbar { topBar }
    }

    /// The navigation bar, the system's: close at the start, Selfie | Studio in the middle and, at the end, the recording's network ("● TikTok",
    /// opens Create for, which sets the ideal length shown above the text, for this session only). Remote is in the bar below, among the
    /// quick adjustments.
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
        if viewModel.hasScript {
            ToolbarItem(placement: .topBarTrailing) {
                let platform = viewModel.platform
                Button { viewModel.platformChipTapped() } label: {
                    HStack(spacing: 6) {
                        PlatformDot(color: platform.tint)
                        Text(platform.label).cueFont(.footnote, weight: .semibold)
                    }
                    .foregroundStyle(Palette.ink)
                }
                .accessibilityLabel(Text("Create for"))
                .accessibilityValue(Text(platform.label))
                .accessibilityIdentifier("prompter.platformButton")
            }
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
