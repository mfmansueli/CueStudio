//
//  SelfieTopBar.swift
//  Cue Studio
//

import SwiftUI

/// The Selfie recorder's navigation bar, the system's: close at the start, Selfie | Studio in the middle and the frame chip at the end.
/// While recording, the REC pill (with the clock) takes the start and the middle stays empty.
struct SelfieTopBar: ToolbarContent {
    let viewModel: PrompterViewModel
    let session: SessionSetupService
    let onClose: () -> Void

    var body: some ToolbarContent {
        if viewModel.isRecording {
            ToolbarItem(placement: .topBarLeading) {
                RecordingBadge(seconds: viewModel.recordingSeconds, monetizationChip: viewModel.monetizationChip)
            }
            .sharedBackgroundVisibility(.hidden)
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

    private var aspectButton: some View {
        let aspect = session.camera.aspect
        let icon = iconSize(for: aspect)
        let label = viewModel.script.map { "\($0.platform.label) · \(aspect.label)" } ?? aspect.label
        return Button {
            viewModel.platformChipTapped()
        } label: {
            HStack(spacing: 6) {
                RoundedRectangle(cornerRadius: 2.5)
                    .strokeBorder(Palette.ink, lineWidth: 1.6)
                    .frame(width: icon.width, height: icon.height)
                Text(label)
                    .font(.footnote.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            }
            .foregroundStyle(Palette.ink)
        }
        .disabled(viewModel.isRecording)
        .accessibilityLabel(Text(viewModel.script.map { "Create for \($0.platform.label), \(aspect.label)" } ?? "Frame \(aspect.label)"))
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
