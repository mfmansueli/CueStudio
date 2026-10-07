//
//  SelfieModeView.swift
//  Cue Studio
//

import SwiftUI

/// The camera first, in layers that never reach the video: the recorded frame (darkened outside),
/// the platform's safe zone, the text window and the reading line, then the controls. The line sits
/// just under the lens and the text scrolls past it; the window follows the line.
struct SelfieModeView: View {
    let viewModel: PrompterViewModel
    let onClose: () -> Void
    /// The practice's two ways out (the first flight): record for real, or go to the studio.
    var onPractice: (PracticeOutcome) -> Void = { _ in }

    @Environment(SessionSetupService.self) private var session
    @Environment(AudioInputManager.self) private var audio
    /// A finger is on the window's corner: the window follows it right away instead of gliding.
    @State private var isResizingWindow = false

    var body: some View {
        let geometry = viewModel.frameGeometry
        ZStack {
            cameraLayers(geometry)
            if viewModel.showsCompactBar {
                // Anywhere on the picture brings the whole bar back for a few seconds.
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture { viewModel.bar.expand() }
                    .accessibilityElement()
                    .accessibilityLabel(Text("Tap the screen for controls"))
                    .accessibilityAddTraits(.isButton)
                    .accessibilityIdentifier("prompter.showControlsArea")
                    .ignoresSafeArea()
            }
            controls
            if let countdown = viewModel.countdown {
                CountdownOverlay(value: countdown, onCancel: { Task { await viewModel.recordButtonTapped() } })
                .transition(.opacity)
            }
        }
        // Close, Selfie | Studio and the frame chip are the system's navigation bar (`SelfieTopBar`), clear over the camera. The practice
        // has its own top bar, placed from the screen's edges.
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackgroundVisibility(.hidden, for: .navigationBar)
        .toolbarVisibility(viewModel.isPractice ? .hidden : .visible, for: .navigationBar)
        .toolbar {
            if !viewModel.isPractice {
                SelfieTopBar(viewModel: viewModel, session: session, onClose: onClose)
            }
        }
    }

    // MARK: - Layers

    private func cameraLayers(_ geometry: FrameGeometry) -> some View {
        ZStack {
            // The practice records nothing: the camera covers the whole screen, with no frame, grid or safe zone.
            let screen = viewModel.screenMetrics.screen
            let sensorRect = FrameGeometry.sensorRect(in: screen, fillsScreen: session.fillsScreen)
            CameraBackdrop(
                sensorRect: viewModel.isPractice ? CGRect(origin: .zero, size: screen) : sensorRect,
                onVideoRectChange: { rect in viewModel.cameraImageMoved(to: rect) },
                fillsScreen: viewModel.isPractice
            )
            if session.camera.showsGrid, !viewModel.isPractice {
                GridOverlay(frame: geometry.frameRect)
            }
            if !viewModel.isPractice {
                FrameGuideOverlay(frame: geometry.frameRect)
            }
            if !viewModel.isPractice, viewModel.showsSafeZone, let zone = viewModel.safeZone, let content = viewModel.safeZoneContentRect {
                let readable = CGRect(x: 0, y: 0, width: screen.width, height: min(screen.height, viewModel.screenMetrics.toolbarTop))
                SafeZoneOverlay(frame: geometry.frameRect, content: content, label: zone.overlayLabel, visible: readable)
                    .animation(.smooth(duration: 0.45), value: readable.height)
                    .transition(.opacity)
            }
            if viewModel.hasScript {
                let layout = viewModel.readingLayout
                textWindow(layout)
                // The pinch's edge sits under the handles: the corner and the line's handle keep their own touches.
                if !viewModel.isRecording, !viewModel.isPractice, viewModel.sheet == nil {
                    ReadingLinePinch(viewModel: viewModel, layout: layout)
                }
                if viewModel.showsTextWindowHandle, !viewModel.isPractice {
                    TextWindowResizeHandle(viewModel: viewModel, layout: layout, isResizing: $isResizingWindow)
                }
                // The practice's line lies under the dim until the creator is counted in (the board).
                if session.prompter.showsGuide, !(viewModel.isPractice && viewModel.practiceStage.isWaiting) {
                    ReadingLineLayer(
                        layout: layout,
                        showsTag: viewModel.sheet == .display,
                        showsHandle: !viewModel.isPlaying && !viewModel.isRecording && !viewModel.isPractice,
                        level: viewModel.followsSpeech ? viewModel.voiceLevel : nil,
                        showsParticles: viewModel.isPlaying,
                        onMove: { viewModel.moveReadingLine(toY: $0) },
                        onNudge: { viewModel.nudgeReadingLine(by: $0) }
                    )
                }
            }
        }
        // Measured inside `ignoresSafeArea`: outside it the size is the safe area's, not the screen's.
        .onGeometryChange(for: CGSize.self) { $0.size } action: { size in
            viewModel.measured { $0.screen = size }
        }
        .ignoresSafeArea()
        .animation(.easeOut(duration: 0.2), value: viewModel.showsSafeZone)
    }

    /// Dark enough to read over any background, with the camera optionally blurred behind the text.
    /// Both only change the preview, never the recording.
    private func textWindow(_ layout: ReadingLayout) -> some View {
        var settings = session.prompter
        let isPractice = viewModel.isPractice
        // The practice reads at the board's 24 pt, a box of five lines, whatever size the creator uses later.
        if isPractice { settings.size = 24 }
        // The practice's box is rounder (28 pt) and darker, and the text recedes (5 pt of blur) until the creator is counted in.
        let shape = RoundedRectangle(cornerRadius: isPractice ? 28 : Metrics.cardRadius, style: .continuous)
        let rect = layout.windowRect
        return PrompterTextView(
            viewModel: viewModel,
            settings: settings,
            viewportHeight: rect.height,
            castsShadow: true,
            guideOffset: layout.lead,
            drawsGuide: false,
            fadesReadText: true
        )
        .blur(radius: isPractice && viewModel.practiceStage.isWaiting ? 5 : 0)
        .animation(.easeOut(duration: 0.4), value: viewModel.practiceStage.isWaiting)
        .background {
            ZStack {
                let blur = CameraBlurLevel(amount: isPractice ? 0.6 : settings.cameraBlur)
                if blur != .off {
                    Rectangle().fill(.ultraThinMaterial).opacity(blur.strength)
                }
                Rectangle().fill(Color.black.opacity(isPractice ? 0.5 : settings.backgroundOpacity))
            }
        }
        .overlay {
            if !isPractice { PrompterTextOverlays(viewModel: viewModel) }
        }
        .overlay {
            if isPractice { PracticeBoxOverlay(stage: viewModel.practiceStage, onPlay: { viewModel.beginPracticeReading() }) }
        }
        .clipShape(shape)
        .overlay(shape.strokeBorder(Palette.Camera.panelBorder, lineWidth: 0.5))
        .frame(width: rect.width, height: rect.height)
        .position(x: rect.midX, y: rect.midY)
        .animation(isResizingWindow ? nil : .smooth(duration: 0.3), value: rect)
    }

    // MARK: - Controls

    @ViewBuilder
    private var controls: some View {
        if viewModel.isPractice { practiceControls } else { recorderControls }
    }

    /// The practice's top bar, the card under its box and the two ways on, placed from the screen's edges as the board has them (the box is
    /// at 100 pt, the card at 372 pt, the buttons 36 pt above the bottom).
    private var practiceControls: some View {
        GeometryReader { proxy in
            ZStack(alignment: .top) {
                PracticeTopBar().frame(height: 32).padding(.top, 56)
                PracticeMessageCard(stage: viewModel.practiceStage)
                    .padding(.horizontal, 16)
                    .padding(.top, 372)
                VStack(spacing: 0) {
                    Spacer(minLength: 0)
                    PracticeBottomBar(viewModel: viewModel, onChoose: onPractice).padding(.bottom, 36)
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height, alignment: .top)
        }
        .ignoresSafeArea()
    }

    private var recorderControls: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)
            if viewModel.showsRecommendation, let recommendation = viewModel.session.recommendation {
                SetupRecommendationCard(
                    recommendation: recommendation,
                    conflicts: viewModel.session.conflicts,
                    usualSummary: viewModel.session.usualSummary,
                    onUseRecommended: { viewModel.useRecommendedSetup() },
                    onKeepSetup: { viewModel.keepCreatorSetup() }
                )
                .padding(.horizontal, 18)
                .padding(.bottom, 12)
                .transition(.scale(scale: 0.9, anchor: .bottom).combined(with: .opacity))
            }
            if !audio.isMicrophoneAllowed, !viewModel.isPractice, !viewModel.isRecording {
                MicrophoneNeededCard()
                    .padding(.horizontal, 18)
                    .padding(.bottom, 12)
                    .transition(.opacity)
            }
            if viewModel.showsStopWarning, let title = viewModel.stopWarningTitle, let message = viewModel.stopWarningMessage {
                StopWarningCard(
                    title: title,
                    message: message,
                    onStop: { Task { await viewModel.stopAnyway() } },
                    onKeepGoing: { viewModel.keepRecording() }
                )
                .padding(.horizontal, 18)
                .padding(.bottom, 12)
                .transition(.scale(scale: 0.9, anchor: .bottom).combined(with: .opacity))
            }
            SelfieControlPanel(viewModel: viewModel)
                .padding(.horizontal, 10)
                .onGeometryChange(for: CGFloat.self) { $0.frame(in: .global).minY } action: { top in
                    viewModel.measured { $0.toolbarTop = top }
                }
        }
        .animation(.spring(duration: 0.3), value: viewModel.showsStopWarning)
        .animation(.spring(duration: 0.3), value: viewModel.showsRecommendation)
        // The controls start under the navigation bar: that is where the text window may begin.
        .onGeometryChange(for: CGFloat.self) { $0.frame(in: .global).minY } action: { top in
            viewModel.measured { $0.topBarBottom = top }
        }
    }
}

#if DEBUG
#Preview {
    let viewModel = PrompterViewModel.preview()
    SelfieModeView(viewModel: viewModel, onClose: {})
        .environment(viewModel.session)
        .previewEnvironment()
}
#endif
