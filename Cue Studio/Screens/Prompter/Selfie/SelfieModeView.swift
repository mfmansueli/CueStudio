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
                .onGeometryChange(for: CGFloat.self) { $0.frame(in: .global).minY } action: { top in
                    viewModel.measured { $0.topInset = top }
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

    // MARK: - Layers

    private func cameraLayers(_ geometry: FrameGeometry) -> some View {
        ZStack {
            // The practice records nothing: the camera covers the whole screen, with no frame, grid or safe zone.
            let screen = viewModel.screenMetrics.screen
            CameraBackdrop(
                sensorRect: viewModel.isPractice ? CGRect(origin: .zero, size: screen) : FrameGeometry.sensorRect(in: screen),
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
                SafeZoneOverlay(frame: geometry.frameRect, content: content, label: zone.overlayLabel)
                    .transition(.opacity)
            }
            if viewModel.hasScript {
                let layout = viewModel.readingLayout
                textWindow(layout)
                // The pinch's edge sits under the handles: the corner and the line's handle keep their own touches.
                if !viewModel.isRecording, viewModel.sheet == nil {
                    ReadingLinePinch(viewModel: viewModel, layout: layout)
                }
                if viewModel.showsTextWindowHandle {
                    TextWindowResizeHandle(viewModel: viewModel, layout: layout, isResizing: $isResizingWindow)
                }
                if session.prompter.showsGuide {
                    ReadingLineLayer(
                        layout: layout,
                        showsTag: viewModel.sheet == .display,
                        showsHandle: !viewModel.isPlaying && !viewModel.isRecording,
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
        let settings = session.prompter
        let shape = RoundedRectangle(cornerRadius: Metrics.cardRadius, style: .continuous)
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
        .background {
            ZStack {
                let blur = CameraBlurLevel(amount: settings.cameraBlur)
                if blur != .off {
                    Rectangle().fill(.ultraThinMaterial).opacity(blur.strength)
                }
                Rectangle().fill(Color.black.opacity(settings.backgroundOpacity))
            }
        }
        .overlay { PrompterTextOverlays(viewModel: viewModel) }
        .clipShape(shape)
        .overlay(shape.strokeBorder(Palette.panelBorder, lineWidth: 0.5))
        .frame(width: rect.width, height: rect.height)
        .position(x: rect.midX, y: rect.midY)
        .animation(isResizingWindow ? nil : .smooth(duration: 0.3), value: rect)
    }

    // MARK: - Controls

    private var controls: some View {
        VStack(spacing: 0) {
            Group {
                if viewModel.isPractice {
                    PracticeTopBar(onClose: onClose)
                } else {
                    SelfieTopBar(viewModel: viewModel, onClose: onClose)
                }
            }
                .padding(.horizontal, 14)
                .onGeometryChange(for: CGFloat.self) { $0.frame(in: .global).maxY } action: { bottom in
                    viewModel.measured { $0.topBarBottom = bottom }
                }
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
            Group {
                if viewModel.isPractice {
                    PracticeBottomBar(viewModel: viewModel, onChoose: onPractice)
                } else {
                    SelfieControlPanel(viewModel: viewModel)
                }
            }
                .padding(.horizontal, 10)
                .onGeometryChange(for: CGFloat.self) { $0.frame(in: .global).minY } action: { top in
                    viewModel.measured { $0.toolbarTop = top }
                }
        }
        .animation(.spring(duration: 0.3), value: viewModel.showsStopWarning)
        .animation(.spring(duration: 0.3), value: viewModel.showsRecommendation)
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
