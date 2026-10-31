//
//  MicrophoneNeededCard.swift
//  Cue Studio
//

import SwiftUI

/// Without the microphone's permission recording is off (04 · F3): the one permission notice, with the way to Settings. The prompter keeps
/// working; only Record waits. Opaque, so it reads over any picture from the camera.
struct MicrophoneNeededCard: View {
    var body: some View {
        PermissionNoticeCard(notice: .microphone, settingsIdentifier: "prompter.openSettingsButton")
            .accessibilityIdentifier("prompter.microphoneCard")
    }
}
