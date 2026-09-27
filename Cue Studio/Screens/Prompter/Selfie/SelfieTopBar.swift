//
//  SelfieTopBar.swift
//  Cue Studio
//

import SwiftUI

/// Close, mode switch and frame; while recording, the clock takes the middle.
struct SelfieTopBar: View {
    let viewModel: PrompterViewModel
    let onClose: () -> Void

    @Environment(PreferencesService.self) private var preferences

    var body: some View {
        HStack {
            if viewModel.isRecording {
                Color.clear.frame(width: 40, height: 40)
            } else {
                Button(action: onClose) { Image(systemName: "xmark") }
                    .buttonStyle(.cueIcon(.glass, diameter: 40))
                    .accessibilityLabel(Text("Close"))
                    .accessibilityIdentifier("prompter.closeButton")
            }
            Spacer(minLength: 8)
            if viewModel.isRecording {
                RecordingBadge(seconds: viewModel.recordingSeconds, monetizationChip: viewModel.monetizationChip)
            } else {
                ModeSwitcher(mode: .selfie) { mode in
                    Task { await viewModel.switchMode(to: mode) }
                }
            }
            Spacer(minLength: 8)
            aspectButton
        }
    }

    private var aspectButton: some View {
        let aspect = preferences.camera.aspect
        let icon = iconSize(for: aspect)
        let label = viewModel.script.map { "\($0.platform.label) · \(aspect.label)" } ?? aspect.label
        return Button {
            viewModel.platformChipTapped()
        } label: {
            HStack(spacing: 6) {
                RoundedRectangle(cornerRadius: 2.5)
                    .strokeBorder(Color.white, lineWidth: 1.6)
                    .frame(width: icon.width, height: icon.height)
                Text(label)
                    .font(.footnote.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 11)
            .frame(minWidth: 40, minHeight: 40)
            .glassEffect(.regular.interactive(), in: Capsule())
        }
        .buttonStyle(.plain)
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
