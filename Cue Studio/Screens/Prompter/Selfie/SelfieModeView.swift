//
//  SelfieModeView.swift
//  Cue Studio
//

import SwiftUI

/// Prompter and camera together: the script floats near the lens while you record yourself.
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
            VStack(spacing: 0) {
                SelfieTopBar(viewModel: viewModel, onClose: onClose)
                    .padding(.horizontal, 14)
                if viewModel.hasScript {
                    prompterPanel
                        .onGeometryChange(for: CGFloat.self) { $0.frame(in: .global).maxY } action: { scriptPanelBottom = $0 }
                        .onDisappear { scriptPanelBottom = nil }
                        .padding(.horizontal, 10)
                        .padding(.top, 8)
                }
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

    private var prompterPanel: some View {
        let settings = preferences.prompter
        let shape = RoundedRectangle(cornerRadius: 30, style: .continuous)
        return PrompterTextView(viewModel: viewModel, settings: settings, viewportHeight: 290)
            .background {
                ZStack {
                    Rectangle().fill(.ultraThinMaterial)
                    Rectangle().fill(Color.black.opacity(settings.dim))
                }
            }
            .clipShape(shape)
            .overlay(shape.strokeBorder(Color.white.opacity(0.1), lineWidth: 0.5))
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
