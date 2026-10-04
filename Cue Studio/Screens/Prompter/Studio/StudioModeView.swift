//
//  StudioModeView.swift
//  Cue Studio
//

import SwiftUI

/// Standalone prompter for rigs and beam-splitter glass. Tap the text to play or pause.
struct StudioModeView: View {
    let viewModel: PrompterViewModel
    let onClose: () -> Void

    @Environment(SessionSetupService.self) private var session

    var body: some View {
        let settings = session.prompter
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
            .padding(.horizontal, 14)
            ProgressLine(viewModel: viewModel)
                .padding(.horizontal, 20)
                .padding(.top, 10)
            GeometryReader { proxy in
                PrompterTextView(
                    viewModel: viewModel,
                    settings: settings,
                    viewportHeight: proxy.size.height,
                    onTap: { viewModel.togglePlay() }
                )
                .overlay { PrompterTextOverlays(viewModel: viewModel) }
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
    let viewModel = PrompterViewModel.preview(scriptID: SampleScripts.weeklyQA.id, mode: .studio)
    StudioModeView(viewModel: viewModel, onClose: {})
        .environment(viewModel.session)
        .previewEnvironment()
}
#endif
