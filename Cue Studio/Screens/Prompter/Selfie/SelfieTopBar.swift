//
//  SelfieTopBar.swift
//  Cue Studio
//

import SwiftUI

/// The Selfie recorder's navigation bar, the system's: close at the start, Selfie | Studio in the middle and the frame chip at the end.
/// While recording, the REC pill (with the clock) takes the start and the take's name (and the time left to the platform's minimum) the middle.
struct SelfieTopBar: ToolbarContent {
    let viewModel: PrompterViewModel
    let session: SessionSetupService
    let onClose: () -> Void

    var body: some ToolbarContent {
        if viewModel.isRecording {
            ToolbarItem(placement: .topBarLeading) {
                RecordingBadge(seconds: viewModel.recordingSeconds)
            }
            .sharedBackgroundVisibility(.hidden)
            // The system's own item, with the system's glass: the take's name is a toolbar item like the others, not a pill of ours.
            ToolbarItem(placement: .principal) {
                RecordingTakeTitle(viewModel: viewModel)
            }
        } else {
            ToolbarItem(placement: .topBarLeading) {
                Button(role: .close, action: onClose)
                    .accessibilityIdentifier("prompter.closeButton")
            }
            ToolbarItem(placement: .principal) {
                ModeSwitcher(mode: .selfie) { mode in
                    Task { await viewModel.switchMode(to: mode) }
                }
            }
        }
        ToolbarItem(placement: .topBarTrailing) {
            aspectButton
        }
    }

    /// The chip at the end of the bar. With a script it is the platform, as in Studio: its colored dot and its name ("● TikTok"), which opens Create
    /// for. With none there is no platform to name, so it is the frame ("9:16" with its shape), and a tap switches to the next one.
    private var aspectButton: some View {
        let aspect = session.camera.aspect
        return Button {
            viewModel.platformChipTapped()
        } label: {
            if let script = viewModel.script {
                HStack(spacing: 6) {
                    PlatformDot(color: script.platform.tint)
                    Text(script.platform.label).font(.footnote.weight(.semibold))
                }
                .foregroundStyle(Palette.ink)
            } else {
                let icon = iconSize(for: aspect)
                HStack(spacing: 6) {
                    RoundedRectangle(cornerRadius: 2.5)
                        .strokeBorder(Palette.ink, lineWidth: 1.6)
                        .frame(width: icon.width, height: icon.height)
                    Text(aspect.label)
                        .font(.footnote.weight(.semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                }
                .foregroundStyle(Palette.ink)
            }
        }
        .disabled(viewModel.isRecording)
        .accessibilityLabel(viewModel.script == nil ? Text("Frame \(aspect.label)") : Text("Create for"))
        .accessibilityValue(Text(viewModel.script?.platform.label ?? ""))
        .accessibilityHint(viewModel.hasScript ? Text("Changes the platform and its preset") : Text("Switches to the next frame"))
        .accessibilityIdentifier("prompter.aspectButton")
    }

    private func iconSize(for aspect: AspectRatio) -> CGSize {
        switch aspect {
        case .portrait: CGSize(width: 8.4, height: 14.4)
        case .vertical: CGSize(width: 10.8, height: 13.2)
        case .square: CGSize(width: 12, height: 12)
        case .landscape: CGSize(width: 15.6, height: 9)
        }
    }
}
