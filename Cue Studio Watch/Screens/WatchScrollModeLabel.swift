//
//  WatchScrollModeLabel.swift
//  Cue Studio Watch
//

import SwiftUI

/// How the script scrolls: Voice Following, or Manual with its speed ("Manual · 1.2×").
struct WatchScrollModeLabel: View {
    let followsVoice: Bool
    let speedMultiple: Double

    var body: some View {
        if followsVoice {
            Label("Voice Following", systemImage: "waveform")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(WatchPalette.voice)
        } else {
            Text("Manual · \(WatchSpeed.label(speedMultiple))")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(WatchPalette.inkMuted)
        }
    }
}
