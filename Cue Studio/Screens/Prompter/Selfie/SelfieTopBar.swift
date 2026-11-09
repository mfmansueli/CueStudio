//
//  SelfieTopBar.swift
//  Cue Studio
//

import SwiftUI

/// The Selfie recorder's navigation bar, the system's: close at the start, Selfie | Studio in the middle and the network chip at the end.
/// While recording, the REC pill (with the clock) takes the start and the take's name (and the time left to the platform's minimum) the middle.
struct SelfieTopBar: ToolbarContent {
    let viewModel: PrompterViewModel
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

    /// The chip at the end of the bar: the network this recording is for, its colored dot and its name ("● TikTok"), the script's or,
    /// freestyle, the creator's default. It opens Create for (the Scripts dock's picker) and changes only this session's network; the
    /// frame lives in the camera pill and the Camera sheet.
    private var aspectButton: some View {
        let platform = viewModel.platform
        return Button {
            viewModel.platformChipTapped()
        } label: {
            HStack(spacing: 6) {
                PlatformDot(color: platform.tint)
                Text(platform.label).cueFont(.footnote, weight: .semibold)
            }
            .foregroundStyle(Palette.ink)
        }
        .disabled(viewModel.isRecording)
        .accessibilityLabel(Text("Create for"))
        .accessibilityValue(Text(platform.label))
        .accessibilityHint(Text("Changes the platform and its preset"))
        .accessibilityIdentifier("prompter.aspectButton")
    }
}
