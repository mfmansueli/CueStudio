//
//  StudioModeView.swift
//  Cue Studio
//

import SwiftUI

/// Standalone prompter for rigs and beam-splitter glass. Tap the text to play or pause.
struct StudioModeView: View {
    let viewModel: PrompterViewModel
    let onClose: () -> Void

    @Environment(PreferencesService.self) private var preferences

    var body: some View {
        let settings = preferences.prompter
        VStack(spacing: 0) {
            HStack {
                Button(action: onClose) { Image(systemName: "xmark") }
                    .buttonStyle(.cueIcon(.glass, diameter: 40))
                    .accessibilityLabel(Text("Close"))
                    .accessibilityIdentifier("prompter.closeButton")
                Spacer()
                ModeSwitcher(mode: .studio) { mode in
                    Task { await viewModel.switchMode(to: mode) }
                }
                Spacer()
                Button {
                    preferences.prompter.isMirrored.toggle()
                } label: {
                    Image(systemName: "arrow.left.and.right.righttriangle.left.righttriangle.right")
                }
                .buttonStyle(.cueIcon(settings.isMirrored ? .accent : .glass, diameter: 40))
                .accessibilityLabel(Text("Mirror text"))
                .accessibilityValue(Text(settings.isMirrored ? "On" : "Off"))
            }
            .padding(.horizontal, 14)
            ProgressLine(viewModel: viewModel)
                .padding(.horizontal, 20)
                .padding(.top, 10)
            GeometryReader { proxy in
                PrompterTextView(
                    viewModel: viewModel,
                    settings: settings,
                    viewportHeight: proxy.size.height,
                    guideArrowSize: 11,
                    onTap: { viewModel.togglePlay() }
                )
            }
            .padding(.top, 5)
            StudioControlPanel(viewModel: viewModel)
                .padding(.horizontal, 10)
        }
        .background(settings.studioBackground.color.ignoresSafeArea())
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
    StudioModeView(
        viewModel: PrompterViewModel(
            launch: PrompterLaunch(scriptID: SampleScripts.weeklyQA.id, mode: .studio),
            library: AppServices.preview.library, takes: AppServices.preview.takes,
            preferences: AppServices.preview.preferences, profile: AppServices.preview.profile,
            camera: AppServices.preview.camera, audio: AppServices.preview.audio,
            speech: AppServices.preview.speech, toast: AppServices.preview.toast
        ),
        onClose: {}
    )
    .previewEnvironment()
}
#endif
