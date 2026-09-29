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

    @Environment(SessionSetupService.self) private var session

    var body: some View {
        let geometry = viewModel.frameGeometry
        ZStack {
            cameraLayers(geometry)
            controls
                .onGeometryChange(for: CGFloat.self) { $0.frame(in: .global).minY } action: { top in
                    viewModel.measured { $0.topInset = top }
                }
            if let countdown = viewModel.countdown {
                CountdownOverlay(value: countdown)
            }
        }
    }

    // MARK: - Layers

    private func cameraLayers(_ geometry: FrameGeometry) -> some View {
        ZStack {
            CameraBackdrop(sensorRect: FrameGeometry.sensorRect(in: viewModel.screenMetrics.screen)) { rect in
                viewModel.cameraImageMoved(to: rect)
            }
            if session.camera.showsGrid {
                GridOverlay(frame: geometry.frameRect)
            }
            FrameGuideOverlay(frame: geometry.frameRect)
            if viewModel.showsSafeZone, let zone = viewModel.safeZone, let content = viewModel.safeZoneContentRect {
                SafeZoneOverlay(frame: geometry.frameRect, content: content, label: zone.overlayLabel)
                    .transition(.opacity)
            }
            if viewModel.hasScript {
                let layout = viewModel.readingLayout
                textWindow(layout)
                if session.prompter.showsGuide {
                    ReadingLineLayer(
                        layout: layout,
                        showsTag: viewModel.sheet == .display,
                        showsHandle: !viewModel.isPlaying && !viewModel.isRecording,
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
        .clipShape(shape)
        .overlay(shape.strokeBorder(Palette.panelBorder, lineWidth: 0.5))
        .frame(width: rect.width, height: rect.height)
        .position(x: rect.midX, y: rect.midY)
        .animation(.smooth(duration: 0.3), value: rect)
    }

    // MARK: - Controls

    private var controls: some View {
        VStack(spacing: 0) {
            SelfieTopBar(viewModel: viewModel, onClose: onClose)
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
            if viewModel.hidesControls {
                CompactStopButton { Task { await viewModel.recordButtonTapped() } }
                    .padding(.bottom, 2)
                    .transition(.opacity)
            } else {
                SelfieControlPanel(viewModel: viewModel)
                    .padding(.horizontal, 10)
                    .onGeometryChange(for: CGFloat.self) { $0.frame(in: .global).minY } action: { top in
                        viewModel.measured { $0.toolbarTop = top }
                    }
                    .transition(.opacity)
            }
        }
        .animation(.spring(duration: 0.3), value: viewModel.showsStopWarning)
        .animation(.spring(duration: 0.3), value: viewModel.showsRecommendation)
        .animation(.easeOut(duration: 0.25), value: viewModel.hidesControls)
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
