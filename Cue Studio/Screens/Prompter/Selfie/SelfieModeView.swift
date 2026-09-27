//
//  SelfieModeView.swift
//  Cue Studio
//

import SwiftUI

/// The camera first, with the script in a floating panel close to the lens. The panel's position
/// and height come from the platform preset, its width from the reading width.
struct SelfieModeView: View {
    let viewModel: PrompterViewModel
    /// Bottom edge of the script panel, from the top of the screen; `nil` while there is no panel.
    @Binding var scriptPanelBottom: CGFloat?
    let onClose: () -> Void

    @Environment(PreferencesService.self) private var preferences

    var body: some View {
        let camera = preferences.camera
        ZStack {
            CameraBackdrop()
            if camera.showsGrid { GridOverlay() }
            FrameGuideOverlay(aspect: camera.aspect)
            if let script = viewModel.script, let preset = viewModel.preset,
               camera.showsSafeZones, camera.aspect == preset.aspect, preset.showsSafeZones {
                SafeZoneOverlay(zones: preset.safeZones, reference: viewModel.layoutReference, platformName: script.platform.label)
            }
            if viewModel.hasScript, let layout = viewModel.preset?.prompter {
                GeometryReader { proxy in
                    let letterboxed = camera.aspect == .landscape && viewModel.preset?.aspect == .landscape
                    let frame = SelfiePanelFrame.frame(
                        layout: layout,
                        readingWidth: preferences.prompter.readingWidth,
                        screen: proxy.size,
                        reference: viewModel.layoutReference,
                        bottomLimit: letterboxed ? FrameGuideLayout.barHeight(for: .landscape, in: proxy.size) : nil
                    )
                    prompterPanel(height: frame.height)
                        .frame(width: frame.width, height: frame.height)
                        .position(x: frame.midX, y: frame.midY)
                        .onGeometryChange(for: CGFloat.self) { $0.frame(in: .global).maxY } action: { scriptPanelBottom = $0 }
                        .onDisappear { scriptPanelBottom = nil }
                        .animation(.smooth(duration: 0.3), value: frame)
                }
                .ignoresSafeArea()
            }
            VStack(spacing: 0) {
                SelfieTopBar(viewModel: viewModel, onClose: onClose)
                    .padding(.horizontal, 14)
                Spacer(minLength: 0)
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
            }
            .animation(.spring(duration: 0.3), value: viewModel.showsStopWarning)
            if let countdown = viewModel.countdown {
                CountdownOverlay(value: countdown)
            }
        }
    }

    /// Dark enough to read over any background, with the camera optionally blurred behind the text.
    /// Both only change the preview, never the recording.
    private func prompterPanel(height: CGFloat) -> some View {
        let settings = preferences.prompter
        let shape = RoundedRectangle(cornerRadius: Metrics.cardRadius, style: .continuous)
        return PrompterTextView(viewModel: viewModel, settings: settings, viewportHeight: height, castsShadow: true)
            .background {
                ZStack {
                    if let material = CameraBlurLevel(amount: settings.cameraBlur).material {
                        Rectangle().fill(material)
                    }
                    Rectangle().fill(Color.black.opacity(settings.backgroundOpacity))
                }
            }
            .clipShape(shape)
            .overlay(shape.strokeBorder(Palette.panelBorder, lineWidth: 0.5))
    }
}

#if DEBUG
#Preview {
    SelfieModeView(
        viewModel: PrompterViewModel(
            launch: PrompterLaunch(scriptID: SampleScripts.morningHabits.id, mode: .selfie),
            library: AppServices.preview.library, takes: AppServices.preview.takes,
            preferences: AppServices.preview.preferences, profile: AppServices.preview.profile, rules: AppServices.preview.rules,
            camera: AppServices.preview.camera, audio: AppServices.preview.audio,
            speech: AppServices.preview.speech, toast: AppServices.preview.toast
        ),
        scriptPanelBottom: .constant(nil),
        onClose: {}
    )
    .previewEnvironment()
}
#endif
