//
//  AudioInputSheet.swift
//  Cue Studio
//

import SwiftUI
import UIKit

/// "Audio Input", from the pill on the recording screen: the recorder's one microphone list (`MicrophoneList`: Automatic and the
/// microphones connected now), the one in use checked. Picking one makes it the input for this recording session and closes the sheet;
/// Settings keeps the usual one.
struct AudioInputSheet: View {
    @Environment(AudioInputManager.self) private var audio
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SheetHeader(
                title: String(localized: "Audio Input"),
                subtitle: String(localized: "Where Cue hears you in this take.")
            )
            .padding(.horizontal, 4)
            .padding(.bottom, 16)

            if !audio.isMicrophoneAllowed {
                deniedMessage
            } else {
                MicrophoneList { dismiss() }
                note(String(localized: "Plug in or pair a mic and it shows up here."))
            }
        }
        .padding(EdgeInsets(top: 20, leading: Metrics.gutter, bottom: 24, trailing: Metrics.gutter))
        .fittedSheet()
        .onAppear { audio.refreshInputs() }
    }

    private var deniedMessage: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Cue can't hear you. Allow the microphone in Settings to record sound.")
                .cueFont(.subheadline)
                .foregroundStyle(Palette.ink2)
                .fixedSize(horizontal: false, vertical: true)
            Button("Open Settings") { openURL.openAppSettings() }
                .buttonStyle(.cueSecondary(.compact, expands: false))
        }
        .padding(.horizontal, 4)
    }

    private func note(_ text: String) -> some View {
        Text(text)
            .cueFont(.footnote)
            .foregroundStyle(Palette.ink2)
            .padding(EdgeInsets(top: 10, leading: 4, bottom: 0, trailing: 4))
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
