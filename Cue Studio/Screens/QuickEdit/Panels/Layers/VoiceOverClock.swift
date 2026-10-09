//
//  VoiceOverClock.swift
//  Cue Studio
//

import SwiftUI

/// "Starts at 00:04.1", or how long it has been recording: reads the player's clock (the
/// microphone's while recording) in its own small view so the panel doesn't redraw while the video plays.
struct VoiceOverClock: View {
    let viewModel: QuickEditViewModel

    var body: some View {
        Text(viewModel.voiceOverTimeLabel)
            .font(.system(.footnote).monospacedDigit())
            .foregroundStyle(Palette.ink2)
            .accessibilityIdentifier("edit.voiceOverTime")
    }
}
