//
//  AudioInputSheet.swift
//  Cue Studio
//

import SwiftUI
import UIKit

/// "Audio Input", from the pill on the recording screen: the microphones connected now, with the
/// one in use selected. Picking one makes it the input for this recording session and closes the
/// sheet; Creator Setup keeps the usual one.
struct AudioInputSheet: View {
    @Environment(SessionSetupService.self) private var session
    @Environment(AudioInputManager.self) private var audio
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SheetHeader(
                title: String(localized: "Audio Input"),
                subtitle: String(localized: "Where Cue hears you in this take."),
                onClose: { dismiss() }
            )
            .padding(.horizontal, 4)
            .padding(.bottom, 16)

            if !audio.isMicrophoneAllowed {
                deniedMessage
            } else if audio.inputs.isEmpty {
                note(String(localized: "No microphone found. Connect one and it shows up here."))
            } else {
                GroupedCard(background: Palette.surface2, radius: Metrics.innerRadius, dividerInset: 48) {
                    ForEach(audio.inputs) { input in
                        row(input)
                    }
                }
                .accessibilityIdentifier("audioInput.list")
                note(String(localized: "Plug in or pair a mic and it shows up here."))
            }
        }
        .padding(EdgeInsets(top: 20, leading: Metrics.gutter, bottom: 24, trailing: Metrics.gutter))
        .fittedSheet()
        .onAppear { audio.refreshInputs() }
    }

    // MARK: - Rows

    private func row(_ input: MicrophoneOption) -> some View {
        let isSelected = input.id == audio.inputInUse?.id
        return Button {
            select(input)
        } label: {
            HStack(spacing: 14) {
                Image(systemName: isSelected ? "largecircle.fill.circle" : "circle")
                    .font(.title3)
                    .foregroundStyle(isSelected ? Palette.accText : Palette.ink3)
                VStack(alignment: .leading, spacing: 1) {
                    Text(input.name)
                        .foregroundStyle(Palette.ink)
                    Text(input.detail)
                        .font(.footnote)
                        .foregroundStyle(Palette.ink2)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 14)
            .frame(minHeight: 56)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityIdentifier("audioInput.option")
    }

    private var deniedMessage: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Cue can't hear you. Allow the microphone in Settings to record sound.")
                .font(.subheadline)
                .foregroundStyle(Palette.ink2)
                .fixedSize(horizontal: false, vertical: true)
            if let url = URL(string: UIApplication.openSettingsURLString) {
                Button("Open Settings") { openURL(url) }
                    .buttonStyle(.cueSecondary(.compact, expands: false))
            }
        }
        .padding(.horizontal, 4)
    }

    private func note(_ text: String) -> some View {
        Text(text)
            .font(.footnote)
            .foregroundStyle(Palette.ink2)
            .padding(EdgeInsets(top: 10, leading: 4, bottom: 0, trailing: 4))
    }

    // MARK: - Actions

    /// For this take: the camera applies the choice from the session every time it starts. The
    /// usual mic is set in Settings › Creator Setup.
    private func select(_ input: MicrophoneOption) {
        var camera = session.camera
        camera.microphoneID = input.id
        camera.microphoneName = input.name
        session.camera = camera
        audio.select(input.id)
        dismiss()
    }
}

#if DEBUG
#Preview {
    Color.black.sheet(isPresented: .constant(true)) {
        AudioInputSheet()
    }
    .environment(SessionSetupService(preferences: AppServices.preview.preferences))
    .previewEnvironment()
}
#endif
